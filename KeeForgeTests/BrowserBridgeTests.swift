#if os(macOS)
import CryptoKit
import XCTest
@testable import KeeForge

@MainActor
final class BrowserBridgeTests: XCTestCase {
    /// A Keychain service of its own per test, so tests never touch the
    /// app's real pairings.
    private var pairings: BrowserBridgePairingStore!
    private let clientKey = Data(repeating: 7, count: 32).base64EncodedString()

    override func setUp() {
        super.setUp()
        pairings = BrowserBridgePairingStore(service: "at.kw.nextpass.browser-pairing.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        pairings.removeAll()
        super.tearDown()
    }

    func testUnpairedClientSeesStatusButNothingElse() async throws {
        let vault = StubVault(entries: [entry(title: "Example", username: "alice", url: "https://example.com")])
        let handler = makeHandler(vault: vault)

        let status = try await send(handler, ["action": "status"])
        XCTAssertEqual(status["paired"] as? Bool, false)
        XCTAssertNil(status["unlocked"], "An unpaired client must not learn whether the vault is unlocked")
        XCTAssertNil(status["database"], "An unpaired client must not learn the database name")

        let search = try await send(handler, ["action": "search", "query": "Example"])
        XCTAssertEqual(search["error"] as? String, "unpaired")
    }

    func testPairingNeedsApprovalAndIsRemembered() async throws {
        var approvals = 0
        let handler = makeHandler(vault: StubVault(entries: []), approve: { approvals += 1; return true })

        let first = try await send(handler, ["action": "pair", "clientName": "Brave", "pairingCode": "123456"])
        let second = try await send(handler, ["action": "pair", "clientName": "Brave", "pairingCode": "123456"])

        XCTAssertEqual(first["paired"] as? Bool, true)
        XCTAssertEqual(second["paired"] as? Bool, true)
        XCTAssertEqual(approvals, 1, "A paired client is not asked about again")
    }

    func testPairingsAreListedByBrowserAndRemovedOneAtATime() throws {
        let chromeKey = Data(repeating: 9, count: 32).base64EncodedString()
        pairings.pair(clientKey, browserName: "Brave")
        pairings.pair(chromeKey, browserName: "Chrome")

        XCTAssertEqual(Set(pairings.pairings.map(\.browserName)), ["Brave", "Chrome"])

        let brave = try XCTUnwrap(pairings.pairings.first { $0.browserName == "Brave" })
        pairings.remove(brave)

        XCTAssertFalse(pairings.isPaired(clientKey))
        XCTAssertTrue(pairings.isPaired(chromeKey))
        XCTAssertEqual(pairings.pairings.map(\.browserName), ["Chrome"])
    }

    func testPairedRequestsRecordLastUseAtMostOncePerInterval() async throws {
        pairings.pair(clientKey, browserName: "Brave")
        XCTAssertNil(pairings.pairings.first?.lastUsedAt)

        var now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let handler = makeHandler(vault: StubVault(entries: []), now: { now })
        _ = try await send(handler, ["action": "status"])
        XCTAssertEqual(pairings.pairings.first?.lastUsedAt, now)

        let recorded = now
        now += BrowserBridgeRequestHandler.useRecordingInterval / 2
        _ = try await send(handler, ["action": "status"])
        XCTAssertEqual(pairings.pairings.first?.lastUsedAt, recorded)

        now += BrowserBridgeRequestHandler.useRecordingInterval
        _ = try await send(handler, ["action": "status"])
        XCTAssertEqual(pairings.pairings.first?.lastUsedAt, now)
    }

    func testShortIDIsTheStartOfTheKeyHash() throws {
        pairings.pair(clientKey, browserName: "Brave")
        let pairing = try XCTUnwrap(pairings.pairings.first)
        XCTAssertEqual(pairing.shortID, String(pairing.id.prefix(4)).uppercased())
        XCTAssertEqual(pairing.shortID.count, 4)
    }

    func testDeniedPairingStaysUnpaired() async throws {
        let handler = makeHandler(vault: StubVault(entries: []), approve: { false })

        let response = try await send(handler, ["action": "pair", "pairingCode": "123456"])
        let status = try await send(handler, ["action": "status"])

        XCTAssertEqual(response["error"] as? String, "pairingDenied")
        XCTAssertEqual(status["paired"] as? Bool, false)
    }

    func testPairingWithoutASixDigitCodeIsRejectedWithoutAPrompt() async throws {
        var prompts = 0
        let handler = makeHandler(vault: StubVault(entries: []), approve: { prompts += 1; return true })

        for code in [nil, "12345", "12345a", "1234567"] as [String?] {
            var request: [String: Any] = ["action": "pair"]
            request["pairingCode"] = code
            let response = try await send(handler, request)
            XCTAssertEqual(response["error"] as? String, "badRequest")
        }
        XCTAssertEqual(prompts, 0)
    }

    /// While one approval dialog is up, another request cannot stack a second.
    func testOnlyOnePairingPromptAtATime() async throws {
        let gate = PromptGate()
        let handler = BrowserBridgeRequestHandler(
            environment: BrowserBridgeRequestHandler.Environment(
                vault: { nil },
                pairings: pairings,
                approvePairing: { _, _ in await gate.wait() },
                presentForUnlock: {},
                copyToClipboard: { _ in }
            )
        )

        let first = Task { @MainActor in
            try await self.send(handler, ["action": "pair", "pairingCode": "123456"])["paired"] as? Bool
        }
        await gate.waitUntilWaiting()
        let second = try await send(handler, ["action": "pair", "pairingCode": "654321"], clientKey: Data(repeating: 9, count: 32).base64EncodedString())
        gate.release(approving: true)

        XCTAssertEqual(second["error"] as? String, "busy")
        let firstPaired = try await first.value
        XCTAssertEqual(firstPaired, true)
    }

    func testPairingPromptsAreRateLimited() async throws {
        var now = Date(timeIntervalSince1970: 1_000)
        let handler = BrowserBridgeRequestHandler(
            environment: BrowserBridgeRequestHandler.Environment(
                vault: { nil },
                pairings: pairings,
                approvePairing: { _, _ in false },
                presentForUnlock: {},
                copyToClipboard: { _ in },
                now: { now }
            )
        )

        for _ in 0..<BrowserBridgeRequestHandler.maxPairingPrompts {
            let response = try await send(handler, ["action": "pair", "pairingCode": "123456"])
            XCTAssertEqual(response["error"] as? String, "pairingDenied")
        }
        let limited = try await send(handler, ["action": "pair", "pairingCode": "123456"])
        XCTAssertEqual(limited["error"] as? String, "tooManyAttempts")

        now += BrowserBridgeRequestHandler.pairingWindow + 1
        let later = try await send(handler, ["action": "pair", "pairingCode": "123456"])
        XCTAssertEqual(later["error"] as? String, "pairingDenied", "The limit lifts once the window has passed")
    }

    func testShortClientKeysAreRejected() async throws {
        let handler = makeHandler(vault: StubVault(entries: []))

        let response = try await send(handler, ["action": "status"], clientKey: Data(count: 8).base64EncodedString())

        XCTAssertEqual(response["error"] as? String, "badRequest")
    }

    /// Searching and filling count as using NextPass, so the auto-lock timer
    /// does not run out underneath an active browser session.
    func testServedRequestsRestartTheAutoLockTimer() async throws {
        let vault = StubVault(entries: [])
        let handler = makeHandler(vault: vault)
        pairings.pair(clientKey, browserName: "Brave")

        _ = try await send(handler, ["action": "status"])
        _ = try await send(handler, ["action": "search", "query": "x"])

        XCTAssertEqual(vault.activityCount, 1, "Only a served vault request counts, not a status poll")
    }

    func testLockedVaultGivesNothingAway() async throws {
        let vault = StubVault(entries: [entry(title: "Example", username: "alice", url: "https://example.com")])
        vault.isBridgeUnlocked = false
        let handler = makeHandler(vault: vault)
        pairings.pair(clientKey, browserName: "Brave")

        let search = try await send(handler, ["action": "search", "query": ""])

        XCTAssertEqual(search["error"] as? String, "locked")
    }

    func testSearchListsSiteMatchesFirstAndQueriesTheWholeVault() async throws {
        let site = entry(title: "Zeta Login", username: "alice", url: "https://example.com")
        let other = entry(title: "Alpha", username: "alice", url: "https://other.test")
        let handler = makeHandler(vault: StubVault(entries: [other, site]))
        pairings.pair(clientKey, browserName: "Brave")

        let forPage = try await send(handler, ["action": "search", "query": "", "url": "https://www.example.com/login"])
        let pageIDs = (forPage["entries"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
        XCTAssertEqual(pageIDs, [site.id.uuidString])

        let queried = try await send(handler, ["action": "search", "query": "alice", "url": "https://www.example.com/login"])
        let queriedIDs = (queried["entries"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
        XCTAssertEqual(queriedIDs, [site.id.uuidString, other.id.uuidString], "Site matches lead a query's results")
    }

    func testCredentialsAreReturnedForOneEntry() async throws {
        let target = entry(title: "Example", username: "alice", url: "https://example.com")
        let handler = makeHandler(vault: StubVault(entries: [target], password: "s3cret"))
        pairings.pair(clientKey, browserName: "Brave")

        let credentials = try await send(handler, ["action": "credentials", "entryId": target.id.uuidString])
        let missing = try await send(handler, ["action": "credentials", "entryId": UUID().uuidString])

        XCTAssertEqual(credentials["username"] as? String, "alice")
        XCTAssertEqual(credentials["password"] as? String, "s3cret")
        XCTAssertEqual(missing["error"] as? String, "notFound")
    }

    /// The password goes to the app's clipboard, not back to the browser.
    func testCopyPasswordUsesTheAppClipboardAndReturnsNoSecret() async throws {
        let target = entry(title: "Example", username: "alice", url: "https://example.com")
        var copied: [String] = []
        let handler = makeHandler(vault: StubVault(entries: [target], password: "s3cret"), copied: { copied.append($0) })

        let unpaired = try await send(handler, ["action": "copyPassword", "entryId": target.id.uuidString])
        pairings.pair(clientKey, browserName: "Brave")
        let response = try await send(handler, ["action": "copyPassword", "entryId": target.id.uuidString])

        XCTAssertEqual(unpaired["error"] as? String, "unpaired")
        XCTAssertEqual(copied, ["s3cret"])
        XCTAssertEqual(response["ok"] as? Bool, true)
        XCTAssertNil(response["password"])
    }

    func testHTTPRequestParsingWaitsForTheWholeBodyAndReadsTheOrigin() {
        let body = #"{"action":"status"}"#
        let head = "POST / HTTP/1.1\r\nHost: 127.0.0.1:19735\r\nOrigin: chrome-extension://abc\r\nContent-Length: \(body.utf8.count)\r\n\r\n"

        XCTAssertEqual(BrowserBridgeHTTP.parse(Data(head.utf8)), .incomplete)
        XCTAssertEqual(
            BrowserBridgeHTTP.parse(Data((head + body).utf8)),
            .complete(BrowserBridgeHTTP.Request(
                method: "POST",
                headers: ["host": "127.0.0.1:19735", "origin": "chrome-extension://abc", "content-length": "\(body.utf8.count)"],
                body: Data(body.utf8)
            ))
        )
    }

    func testMalformedAndOversizedRequestsAreInvalid() {
        XCTAssertEqual(BrowserBridgeHTTP.parse(Data("GARBAGE\r\n\r\n".utf8)), .invalid)
        XCTAssertEqual(BrowserBridgeHTTP.parse(Data(count: BrowserBridgeHTTP.maxRequestBytes + 1)), .invalid)
    }

    // MARK: - Helpers

    private func makeHandler(
        vault: StubVault?,
        approve: @escaping @MainActor () -> Bool = { true },
        copied: @escaping @MainActor (String) -> Void = { _ in },
        now: @escaping @MainActor () -> Date = { .now }
    ) -> BrowserBridgeRequestHandler {
        BrowserBridgeRequestHandler(
            environment: BrowserBridgeRequestHandler.Environment(
                vault: { vault },
                pairings: pairings,
                approvePairing: { _, _ in approve() },
                presentForUnlock: {},
                copyToClipboard: copied,
                now: now
            )
        )
    }

    private func send(
        _ handler: BrowserBridgeRequestHandler,
        _ request: [String: Any],
        clientKey: String? = nil
    ) async throws -> [String: Any] {
        var request = request
        request["clientKey"] = clientKey ?? self.clientKey
        let data = try JSONSerialization.data(withJSONObject: request)
        let response = await handler.handle(data)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
    }

    private func entry(title: String, username: String, url: String) -> KPEntry {
        KPEntry(title: title, username: username, url: url)
    }

    /// Holds a pairing prompt open until the test releases it.
    @MainActor
    private final class PromptGate {
        private var continuation: CheckedContinuation<Bool, Never>?

        func wait() async -> Bool {
            await withCheckedContinuation { continuation = $0 }
        }

        func waitUntilWaiting() async {
            while continuation == nil { await Task.yield() }
        }

        func release(approving: Bool) {
            continuation?.resume(returning: approving)
            continuation = nil
        }
    }

    private final class StubVault: BrowserBridgeVault {
        var isBridgeUnlocked = true
        let bridgeDatabaseName = "Personal"
        let entries: [KPEntry]
        let password: String

        init(entries: [KPEntry], password: String = "") {
            self.entries = entries
            self.password = password
        }

        func bridgeEntries() -> [KPEntry] { entries }
        func bridgeUsername(for entry: KPEntry) -> String { entry.username }
        func bridgePassword(for entry: KPEntry) -> String { password }
        private(set) var activityCount = 0
        func noteBridgeActivity() { activityCount += 1 }
    }
}
#endif
