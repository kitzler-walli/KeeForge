#if os(macOS)
import CryptoKit
import XCTest
@testable import KeeForge

@MainActor
final class BrowserBridgeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let clientKey = Data(repeating: 7, count: 32).base64EncodedString()

    override func setUp() {
        super.setUp()
        suiteName = "BrowserBridgeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testUnpairedClientSeesStatusButNothingElse() async throws {
        let vault = StubVault(entries: [entry(title: "Example", username: "alice", url: "https://example.com")])
        let handler = makeHandler(vault: vault)

        let status = try await send(handler, ["action": "status"])
        XCTAssertEqual(status["paired"] as? Bool, false)
        XCTAssertEqual(status["unlocked"] as? Bool, true)
        XCTAssertNil(status["database"], "An unpaired client must not learn the database name")

        let search = try await send(handler, ["action": "search", "query": "Example"])
        XCTAssertEqual(search["error"] as? String, "unpaired")
    }

    func testPairingNeedsApprovalAndIsRemembered() async throws {
        var approvals = 0
        let handler = makeHandler(vault: StubVault(entries: []), approve: { approvals += 1; return true })

        let first = try await send(handler, ["action": "pair", "clientName": "Brave"])
        let second = try await send(handler, ["action": "pair", "clientName": "Brave"])

        XCTAssertEqual(first["paired"] as? Bool, true)
        XCTAssertEqual(second["paired"] as? Bool, true)
        XCTAssertEqual(approvals, 1, "A paired client is not asked about again")
    }

    func testDeniedPairingStaysUnpaired() async throws {
        let handler = makeHandler(vault: StubVault(entries: []), approve: { false })

        let response = try await send(handler, ["action": "pair"])
        let status = try await send(handler, ["action": "status"])

        XCTAssertEqual(response["error"] as? String, "pairingDenied")
        XCTAssertEqual(status["paired"] as? Bool, false)
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
        BrowserBridgePairingStore(defaults: defaults).pair(clientKey)

        _ = try await send(handler, ["action": "status"])
        _ = try await send(handler, ["action": "search", "query": "x"])

        XCTAssertEqual(vault.activityCount, 1, "Only a served vault request counts, not a status poll")
    }

    func testLockedVaultGivesNothingAway() async throws {
        let vault = StubVault(entries: [entry(title: "Example", username: "alice", url: "https://example.com")])
        vault.isBridgeUnlocked = false
        let handler = makeHandler(vault: vault)
        BrowserBridgePairingStore(defaults: defaults).pair(clientKey)

        let search = try await send(handler, ["action": "search", "query": ""])

        XCTAssertEqual(search["error"] as? String, "locked")
    }

    func testSearchListsSiteMatchesFirstAndQueriesTheWholeVault() async throws {
        let site = entry(title: "Zeta Login", username: "alice", url: "https://example.com")
        let other = entry(title: "Alpha", username: "alice", url: "https://other.test")
        let handler = makeHandler(vault: StubVault(entries: [other, site]))
        BrowserBridgePairingStore(defaults: defaults).pair(clientKey)

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
        BrowserBridgePairingStore(defaults: defaults).pair(clientKey)

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
        BrowserBridgePairingStore(defaults: defaults).pair(clientKey)
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
        copied: @escaping @MainActor (String) -> Void = { _ in }
    ) -> BrowserBridgeRequestHandler {
        BrowserBridgeRequestHandler(
            environment: BrowserBridgeRequestHandler.Environment(
                vault: { vault },
                pairings: BrowserBridgePairingStore(defaults: defaults),
                approvePairing: { _ in approve() },
                presentForUnlock: {},
                copyToClipboard: copied
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
