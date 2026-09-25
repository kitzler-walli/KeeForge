import XCTest

/// End-to-end Nextcloud Login Flow v2 against a real server — no provider
/// double. Opt-in: skipped unless the runner gets `NEXTCLOUD_E2E_URL`
/// (pass `TEST_RUNNER_NEXTCLOUD_E2E_URL=http://localhost:8480` to
/// `xcodebuild`). `scripts/nextcloud-e2e/up.sh` starts a matching server with
/// `test.kdbx` at `/Vaults/nextpass-e2e.kdbx`; `verify.sh` there checks the
/// entry this test saves back.
@MainActor
final class NextcloudLoginFlowE2EUITests: KeeForgeUITestCase {
    private var serverURL = ""
    private var loginName = ""
    private var loginPassword = ""

    override var databaseFixtures: [KeeForgeUITestCase.DatabaseFixture] {
        []
    }

    override func setUp() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["NEXTCLOUD_E2E_URL"], url.isEmpty == false else {
            throw XCTSkip("Set TEST_RUNNER_NEXTCLOUD_E2E_URL to run the Nextcloud end-to-end test.")
        }
        serverURL = url
        loginName = environment["NEXTCLOUD_E2E_USER"] ?? "e2e-admin"
        loginPassword = environment["NEXTCLOUD_E2E_PASSWORD"] ?? "e2e-admin-password"
        try await super.setUp()
    }

    static let watchEntryTitle = "Watch E2E"
    static let watchTag = "Apple Watch"

    func testLoginFlowV2ConnectsOpensAndSavesTaggedEntry() {
        signInWithNextcloud()
        openRemoteDatabase(folder: "Vaults", file: "nextpass-e2e.kdbx")
        unlockSuccessfully()
        createWatchEntry()
    }

    // MARK: - Flow

    private func signInWithNextcloud() {
        let addButton = app.buttons["database.empty.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.ciElementTimeout), "Empty-state add button did not appear")
        addButton.tap()

        let nextcloudButton = menuButton(identifier: "database.add.nextcloud", label: "Nextcloud")
        XCTAssertTrue(nextcloudButton.waitForExistence(timeout: 10), "Nextcloud add-menu entry did not appear")
        nextcloudButton.tap()

        let connectButton = app.buttons["cloud.browser.connect.button"].firstMatch
        XCTAssertTrue(connectButton.waitForExistence(timeout: 10), "Cloud browser connect button did not appear")
        connectButton.tap()

        let serverField = app.textFields["webdav.connect.server-field"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 10), "WebDAV connect form did not appear")
        replaceText(in: serverField, with: serverURL)

        let allowHTTP = app.switches["webdav.connect.allow-http-toggle"]
        _ = revealElement(allowHTTP)
        setSwitch(allowHTTP, isOn: true)

        let signInButton = app.buttons["webdav.connect.nextcloud-signin"]
        _ = revealElement(signInButton)
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Sign in with Nextcloud button missing")
        signInButton.tap()

        completeBrowserLogin()
    }

    /// Drives the `ASWebAuthenticationSession` sheet: the system consent
    /// alert, Nextcloud's "Log in" landing page, the credential form (skipped
    /// when the shared browser session is still signed in), and the grant page.
    private func completeBrowserLogin() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let consent = springboard.buttons["Continue"]
        if consent.waitForExistence(timeout: 15) {
            consent.tap()
        }

        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 30), "Nextcloud login page did not open\n\(app.debugDescription)")

        let landingLogin = web.buttons["Log in"].firstMatch
        if landingLogin.waitForExistence(timeout: 15) {
            landingLogin.tap()
        }

        let userField = web.textFields.firstMatch
        let grantButton = web.buttons["Grant access"].firstMatch
        _ = waitForAny([userField, grantButton], timeout: 30)
        if userField.exists, grantButton.exists == false {
            userField.tap()
            userField.typeText(loginName)
            let passwordField = web.secureTextFields.firstMatch
            passwordField.tap()
            passwordField.typeText(loginPassword)
            web.buttons.matching(NSPredicate(format: "label ==[c] 'Log in'")).firstMatch.tap()

            // The web view offers to save the typed password over the grant page.
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 10) {
                notNow.tap()
            }
        }

        XCTAssertTrue(
            grantButton.waitForExistence(timeout: 30),
            "Nextcloud grant page did not appear\n\(app.debugDescription)"
        )

        // A tap that lands while the grant page is still settling is dropped
        // without submitting, so re-tap until the poll resolves and the
        // browser sheet gives way to the file list.
        // A reused browser session whose last password entry is stale makes
        // Nextcloud confirm the password before it grants.
        let fileRow = app.buttons["cloud.browser.file.row"].firstMatch
        let confirmButton = web.buttons["Confirm"].firstMatch
        for _ in 1...3 {
            if grantButton.exists, grantButton.isHittable {
                grantButton.tap()
            }
            if confirmButton.waitForExistence(timeout: 5) {
                let confirmField = web.secureTextFields.firstMatch
                confirmField.tap()
                confirmField.typeText(loginPassword)
                confirmButton.tap()
            }
            if fileRow.waitForExistence(timeout: 20) {
                return
            }
        }
        XCTFail("The cloud browser did not list the Nextcloud files after Login Flow v2\n\(app.debugDescription)")
    }

    private func openRemoteDatabase(folder: String, file: String) {
        let folderRow = browserRow(named: folder)
        XCTAssertTrue(folderRow.waitForExistence(timeout: 30), "\(folder) folder did not appear in the cloud browser")
        folderRow.tap()

        let fileRow = browserRow(named: file)
        XCTAssertTrue(fileRow.waitForExistence(timeout: 30), "\(file) did not appear in the cloud browser")
        fileRow.staticTexts[file].firstMatch.tap()

        XCTAssertTrue(
            app.secureTextFields["unlock.password.field"].waitForExistence(timeout: 30),
            "Selecting \(file) did not open its unlock screen"
        )
    }

    /// Saves an entry carrying every field the Watch companion shows, tagged
    /// for it. The save uploads straight back to Nextcloud.
    private func createWatchEntry() {
        let addButton = app.buttons["entry-list.add-entry"]
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.ciElementTimeout), "Add menu button was not visible")
        let newEntryItem = app.buttons["New Entry"]
        for _ in 0..<4 where newEntryItem.exists == false {
            addButton.tap()
            _ = newEntryItem.waitForExistence(timeout: 2)
        }
        newEntryItem.tap()

        let titleField = app.textFields["entry-edit.title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field was not visible")
        replaceText(in: titleField, with: Self.watchEntryTitle)
        replaceText(in: app.textFields["entry-edit.username-field"], with: "watch-user")
        replaceText(in: app.textFields["entry-edit.password-field"], with: "WatchSecret-42")

        let tagsField = app.textFields["entry-edit.tags-field"]
        XCTAssertTrue(revealElement(tagsField, in: scrollableContainer()), "Tags field was not visible")
        tagsField.tap()
        tagsField.typeText("\(Self.watchTag)\n")

        let enterLinkButton = app.buttons["entry-edit.totp.enter-link"]
        XCTAssertTrue(revealElement(enterLinkButton, in: scrollableContainer()), "Enter Setup Link button was not visible")
        tapElement(enterLinkButton)
        let linkField = app.textFields["entry-edit.totp.link-field"]
        XCTAssertTrue(linkField.waitForExistence(timeout: 5), "Setup link field was not visible")
        replaceText(in: linkField, with: "otpauth://totp/NextPass:watch-user?secret=JBSWY3DPEHPK3PXP&issuer=NextPass")
        tapElement(app.buttons["entry-edit.totp.link-apply"])
        XCTAssertTrue(linkField.waitForNonExistence(timeout: 10), "Setup link sheet did not dismiss")

        let saveButton = app.buttons["entry-edit.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Entry editor save button was not visible")
        tapElement(saveButton)
        XCTAssertTrue(saveButton.waitForNonExistence(timeout: 30), "Entry editor did not dismiss after saving to Nextcloud")

        let savedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.watchEntryTitle)).firstMatch
        XCTAssertTrue(savedRow.waitForExistence(timeout: 15), "Saved entry did not appear in the list")
    }

    // MARK: - Helpers

    private func browserRow(named name: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == 'cloud.browser.file.row' AND label CONTAINS[c] %@", name)
        ).firstMatch
    }

    @discardableResult
    private func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if elements.contains(where: \.exists) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return false
    }
}
