#if os(macOS)
import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// What the browser bridge needs from an open database session.
/// `DatabaseViewModel` conforms; tests supply a stub.
@MainActor
protocol BrowserBridgeVault: AnyObject {
    var isBridgeUnlocked: Bool { get }
    var bridgeDatabaseName: String { get }
    /// The entries AutoFill would offer: no recycle bin, no groups with
    /// searching off, nothing expired.
    func bridgeEntries() -> [KPEntry]
    func bridgeUsername(for entry: KPEntry) -> String
    func bridgePassword(for entry: KPEntry) -> String
    /// Using the extension is using NextPass: it restarts the auto-lock timer.
    func noteBridgeActivity()
}

/// Answers one browser-extension request. Every action except `status` and
/// `pair` requires a paired client key, and secrets leave only through
/// `credentials`, for one entry, while the vault is unlocked.
@MainActor
final class BrowserBridgeRequestHandler {
    struct Environment {
        var vault: @MainActor () -> BrowserBridgeVault?
        var pairings: BrowserBridgePairingStore
        /// Asks the user, in NextPass, whether to allow the named browser
        /// that shows `code` in its popup.
        var approvePairing: @MainActor (_ browserName: String, _ code: String) async -> Bool
        /// Brings NextPass forward so the user can unlock it.
        var presentForUnlock: @MainActor () -> Void
        /// Puts a password on the clipboard the way the app does (concealed,
        /// cleared after the timeout and on lock), so it never passes
        /// through the browser.
        var copyToClipboard: @MainActor (String) -> Void
        var now: @MainActor () -> Date = { .now }
    }

    static let maxSearchResults = 50
    /// Pairing prompts allowed per `pairingWindow`: a local process must not
    /// be able to bury the user in dialogs until one is clicked through.
    static let maxPairingPrompts = 3
    static let pairingWindow: TimeInterval = 5 * 60

    private let environment: Environment
    private var isPairingPromptShown = false
    private var recentPairingPrompts: [Date] = []
    /// When each paired client's use was last written to its Keychain item;
    /// throttled so a popup's status polls do not write on every request.
    private var lastRecordedUse: [String: Date] = [:]
    static let useRecordingInterval: TimeInterval = 60

    init(environment: Environment) {
        self.environment = environment
    }

    func handle(_ requestData: Data) async -> Data {
        let response: [String: Any]
        if let request = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any] {
            response = await handle(request)
        } else {
            response = Self.failure("badRequest")
        }
        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }

    private func handle(_ request: [String: Any]) async -> [String: Any] {
        guard let action = request["action"] as? String,
              let clientKey = request["clientKey"] as? String,
              BrowserBridgePairingStore.isWellFormed(clientKey) else {
            return Self.failure("badRequest")
        }
        let isPaired = environment.pairings.isPaired(clientKey)
        if isPaired { recordUse(of: clientKey) }

        switch action {
        case "status":
            // Nothing about the vault — not even whether it is unlocked —
            // until the caller is paired.
            guard isPaired else { return ["ok": true, "paired": false] }
            let vault = environment.vault()
            var status: [String: Any] = [
                "ok": true,
                "paired": true,
                "unlocked": vault?.isBridgeUnlocked == true,
            ]
            if let vault {
                status["database"] = vault.bridgeDatabaseName
            }
            return status
        case "pair":
            if isPaired { return ["ok": true, "paired": true] }
            return await pair(clientKey: clientKey, request: request)
        default:
            break
        }

        guard isPaired else { return Self.failure("unpaired") }

        if action == "unlock" {
            environment.presentForUnlock()
            return ["ok": true]
        }

        guard let vault = environment.vault(), vault.isBridgeUnlocked else {
            return Self.failure("locked")
        }
        vault.noteBridgeActivity()

        switch action {
        case "search":
            return ["ok": true, "entries": search(vault: vault, request: request)]
        case "credentials", "copyPassword":
            guard let rawID = request["entryId"] as? String,
                  let entryID = UUID(uuidString: rawID),
                  let entry = vault.bridgeEntries().first(where: { $0.id == entryID }) else {
                return Self.failure("notFound")
            }
            if action == "copyPassword" {
                environment.copyToClipboard(vault.bridgePassword(for: entry))
                return ["ok": true]
            }
            return [
                "ok": true,
                "username": vault.bridgeUsername(for: entry),
                "password": vault.bridgePassword(for: entry),
            ]
        default:
            return Self.failure("badRequest")
        }
    }

    /// The popup shows a random code and NextPass asks the user whether the
    /// browser shows the same one, so a prompt raised by anything other than
    /// the extension the user is looking at cannot be matched. One prompt at a
    /// time, a few per window.
    private func pair(clientKey: String, request: [String: Any]) async -> [String: Any] {
        guard let code = request["pairingCode"] as? String,
              code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return Self.failure("badRequest")
        }
        guard isPairingPromptShown == false else { return Self.failure("busy") }
        let now = environment.now()
        recentPairingPrompts.removeAll { now.timeIntervalSince($0) > Self.pairingWindow }
        guard recentPairingPrompts.count < Self.maxPairingPrompts else {
            return Self.failure("tooManyAttempts")
        }

        recentPairingPrompts.append(now)
        isPairingPromptShown = true
        defer { isPairingPromptShown = false }
        let browserName = (request["clientName"] as? String).map { String($0.prefix(40)) } ?? "Browser"
        guard await environment.approvePairing(browserName, code) else {
            return Self.failure("pairingDenied")
        }
        environment.pairings.pair(clientKey, browserName: browserName)
        return ["ok": true, "paired": true]
    }

    /// With no query, the entries matching the page; with one, every entry
    /// whose title, user name, or address contains it, page matches first.
    private func search(vault: BrowserBridgeVault, request: [String: Any]) -> [[String: Any]] {
        let entries = vault.bridgeEntries()
        let pageURL = (request["url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let siteMatchIDs = Set(pageURL.map { url in
            CredentialMatcher.matchedEntries(
                from: entries,
                for: [ASCredentialServiceIdentifier(identifier: url, type: .URL)]
            ).map(\.id)
        } ?? [])
        let query = (request["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let results = entries
            .filter { entry in
                guard query.isEmpty == false else { return siteMatchIDs.contains(entry.id) }
                let username = vault.bridgeUsername(for: entry)
                return entry.title.localizedCaseInsensitiveContains(query)
                    || username.localizedCaseInsensitiveContains(query)
                    || entry.url.localizedCaseInsensitiveContains(query)
            }
            .sorted { lhs, rhs in
                let lhsMatch = siteMatchIDs.contains(lhs.id)
                let rhsMatch = siteMatchIDs.contains(rhs.id)
                if lhsMatch != rhsMatch { return lhsMatch }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .prefix(Self.maxSearchResults)

        return results.map { entry in
            [
                "id": entry.id.uuidString,
                "title": entry.title,
                "username": vault.bridgeUsername(for: entry),
                "url": entry.url,
                "siteMatch": siteMatchIDs.contains(entry.id),
            ]
        }
    }

    private func recordUse(of clientKey: String) {
        let now = environment.now()
        if let last = lastRecordedUse[clientKey], now.timeIntervalSince(last) < Self.useRecordingInterval { return }
        lastRecordedUse[clientKey] = now
        environment.pairings.recordUse(of: clientKey, at: now)
    }

    private static func failure(_ error: String) -> [String: Any] {
        ["ok": false, "error": error]
    }
}

/// Browser extensions the user approved, remembered by a hash of the random
/// key each extension generated for itself. In the Keychain, not the app's
/// preferences: any process running as the user can edit the preferences
/// file, but none outside this team can add items to NextPass's keychain
/// access group, so nothing can approve itself behind the user's back.
final class BrowserBridgePairingStore: @unchecked Sendable {
    static let defaultService = "at.kw.nextpass.browser-pairing"
    static let didChangeNotification = Notification.Name("KeeForge.browserPairingsDidChange")

    private let service: String

    init(service: String = defaultService) {
        self.service = service
    }

    /// A base64 key of at least 32 bytes, so a guessable key can never pair.
    static func isWellFormed(_ clientKey: String) -> Bool {
        (Data(base64Encoded: clientKey)?.count ?? 0) >= 32
    }

    func isPaired(_ clientKey: String) -> Bool {
        var query = baseQuery
        query[kSecAttrAccount as String] = Self.hash(clientKey)
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func pair(_ clientKey: String, browserName: String) {
        var item = baseQuery
        item[kSecAttrAccount as String] = Self.hash(clientKey)
        item[kSecAttrLabel as String] = browserName
        item[kSecValueData as String] = Data()
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    struct Pairing: Identifiable, Equatable {
        /// The hash of the extension's key, which is also the item's account.
        let id: String
        let browserName: String
        let pairedAt: Date
        let lastUsedAt: Date?

        /// Also shown at the bottom of the extension's popup, which hashes
        /// its own key the same way, so the user can tell pairings apart.
        var shortID: String { String(id.prefix(4)).uppercased() }
    }

    /// Oldest first.
    var pairings: [Pairing] {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item -> Pairing? in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            return Pairing(
                id: account,
                browserName: item[kSecAttrLabel as String] as? String ?? "",
                pairedAt: item[kSecAttrCreationDate as String] as? Date ?? .distantPast,
                lastUsedAt: (item[kSecAttrGeneric as String] as? Data)
                    .flatMap { String(data: $0, encoding: .utf8) }
                    .flatMap(TimeInterval.init)
                    .map(Date.init(timeIntervalSinceReferenceDate:))
            )
        }
        .sorted { $0.pairedAt < $1.pairedAt }
    }

    func recordUse(of clientKey: String, at date: Date) {
        var query = baseQuery
        query[kSecAttrAccount as String] = Self.hash(clientKey)
        let update = [kSecAttrGeneric as String: Data(String(date.timeIntervalSinceReferenceDate).utf8)]
        guard SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess else { return }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func remove(_ pairing: Pairing) {
        var query = baseQuery
        query[kSecAttrAccount as String] = pairing.id
        SecItemDelete(query as CFDictionary)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func removeAll() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private static func hash(_ clientKey: String) -> String {
        SHA256.hash(data: Data(clientKey.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension DatabaseViewModel: BrowserBridgeVault {
    var isBridgeUnlocked: Bool {
        if case .unlocked = state { return true }
        return false
    }

    var bridgeDatabaseName: String { databaseDisplayName }

    func bridgeEntries() -> [KPEntry] {
        currentRootGroup.map(Self.credentialStoreEntries(from:)) ?? []
    }

    func bridgeUsername(for entry: KPEntry) -> String {
        resolvingFieldReferences(entry.username)
    }

    func bridgePassword(for entry: KPEntry) -> String {
        resolvedPassword(for: entry)
    }

    func noteBridgeActivity() {
        resetInactivityTimer()
    }
}
#endif
