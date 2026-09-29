#if os(macOS)
import AuthenticationServices
import CryptoKit
import Foundation

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
        /// Asks the user, in NextPass, whether to allow the named browser.
        var approvePairing: @MainActor (_ browserName: String) async -> Bool
        /// Brings NextPass forward so the user can unlock it.
        var presentForUnlock: @MainActor () -> Void
        /// Puts a password on the clipboard the way the app does (concealed,
        /// cleared after the timeout and on lock), so it never passes
        /// through the browser.
        var copyToClipboard: @MainActor (String) -> Void
    }

    static let maxSearchResults = 50

    private let environment: Environment

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

        switch action {
        case "status":
            let vault = environment.vault()
            var status: [String: Any] = [
                "ok": true,
                "paired": isPaired,
                "unlocked": vault?.isBridgeUnlocked == true,
            ]
            if isPaired, let vault {
                status["database"] = vault.bridgeDatabaseName
            }
            return status
        case "pair":
            if isPaired { return ["ok": true, "paired": true] }
            let browserName = (request["clientName"] as? String).map { String($0.prefix(40)) } ?? "Browser"
            guard await environment.approvePairing(browserName) else {
                return Self.failure("pairingDenied")
            }
            environment.pairings.pair(clientKey)
            return ["ok": true, "paired": true]
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

    private static func failure(_ error: String) -> [String: Any] {
        ["ok": false, "error": error]
    }
}

/// Browser extensions the user approved, remembered by a hash of the random
/// key each extension generated for itself. App-local; nothing secret is
/// stored, since the hash cannot be turned back into a usable key.
final class BrowserBridgePairingStore: @unchecked Sendable {
    static let defaultsKey = "KeeForge.browserBridgePairings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// A base64 key of at least 32 bytes, so a guessable key can never pair.
    static func isWellFormed(_ clientKey: String) -> Bool {
        (Data(base64Encoded: clientKey)?.count ?? 0) >= 32
    }

    func isPaired(_ clientKey: String) -> Bool {
        pairedHashes.contains(Self.hash(clientKey))
    }

    func pair(_ clientKey: String) {
        defaults.set(Array(pairedHashes.union([Self.hash(clientKey)])), forKey: Self.defaultsKey)
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    var hasPairings: Bool {
        pairedHashes.isEmpty == false
    }

    private var pairedHashes: Set<String> {
        Set(defaults.stringArray(forKey: Self.defaultsKey) ?? [])
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
