import CryptoKit
import XCTest

/// Checks the entry `NextcloudLoginFlowE2EUITests` saved and synced to this
/// Watch, with the iPhone switched off: the TOTP code must be computed on the
/// Watch. Opt-in, like that test: skipped unless the runner gets
/// `WATCH_E2E_EXPECT_SYNC=1` (pass `TEST_RUNNER_WATCH_E2E_EXPECT_SYNC=1`).
@MainActor
final class WatchOfflineTOTPUITests: XCTestCase {
    /// The secret the iPhone test enrolls (`otpauth://…?secret=JBSWY3DPEHPK3PXP`).
    private static let secret = Data("Hello!\u{DE}\u{AD}\u{BE}\u{EF}".unicodeScalars.map { UInt8($0.value) })

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["WATCH_E2E_EXPECT_SYNC"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_WATCH_E2E_EXPECT_SYNC=1 after syncing the Nextcloud e2e entry.")
        }
        continueAfterFailure = false
    }

    func testSyncedEntryShowsFieldsAndComputesTOTPOffline() throws {
        let app = XCUIApplication()
        app.launch()

        let row = app.buttons.matching(identifier: "watch.entry.row")
            .matching(NSPredicate(format: "label CONTAINS 'Watch E2E'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Synced entry is missing\n\(app.debugDescription)")
        row.tap()

        let code = app.staticTexts["watch.entry.totp"]
        XCTAssertTrue(code.waitForExistence(timeout: 10), "TOTP code is missing\n\(app.debugDescription)")
        let shown = code.label.replacingOccurrences(of: " ", with: "")
        let now = Date()
        let expected = [now.addingTimeInterval(-30), now, now.addingTimeInterval(30)].map(Self.expectedCode)
        XCTAssertTrue(expected.contains(shown), "Watch showed \(shown), expected one of \(expected)")

        XCTAssertEqual(app.staticTexts["watch.entry.username"].label, "watch-user")
        let password = app.buttons["watch.entry.password"]
        for _ in 0..<4 where password.isHittable == false {
            app.swipeUp()
        }
        password.tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == 'WatchSecret-42'")).firstMatch.waitForExistence(timeout: 5),
            "Revealed password did not match\n\(app.debugDescription)"
        )
    }

    /// Independent RFC 6238 SHA-1, 6 digits, 30 s — not the app's TOTPCode.
    private static func expectedCode(at date: Date) -> String {
        var counter = UInt64(date.timeIntervalSince1970 / 30).bigEndian
        let message = Data(bytes: &counter, count: 8)
        let mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: secret)))
        let offset = Int(mac[19] & 0x0F)
        let value = (UInt32(mac[offset] & 0x7F) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])
        return String(format: "%06d", value % 1_000_000)
    }
}
