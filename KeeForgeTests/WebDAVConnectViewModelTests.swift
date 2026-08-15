import AuthenticationServices
import XCTest
@testable import KeeForge

@MainActor
final class WebDAVConnectViewModelTests: XCTestCase {
    func testConnectRejectsEmptyServerURLWithoutCallingProvider() async {
        let connector = MockWebDAVConnector()
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "   "
        viewModel.username = "alex"
        viewModel.password = "secret"

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isConnecting)
    }

    func testConnectRejectsEmptyUsernameWithoutCallingProvider() async {
        let connector = MockWebDAVConnector()
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "https://cloud.example.com/"
        viewModel.username = ""
        viewModel.password = "secret"

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testConnectRejectsEmptyPasswordWithoutCallingProvider() async {
        let connector = MockWebDAVConnector()
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "https://cloud.example.com/"
        viewModel.username = "alex"
        viewModel.password = ""

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testConnectRejectsHTTPURLBeforeCallingProvider() async {
        let connector = MockWebDAVConnector()
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "http://cloud.example.com/"
        viewModel.username = "alex"
        viewModel.password = "secret"

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 0)
        XCTAssertEqual(
            viewModel.errorMessage,
            String(localized: "Turn on Allow Unencrypted HTTP in Advanced to use an http:// server address.")
        )
        XCTAssertFalse(viewModel.isConnecting)
    }

    func testConnectAllowsHTTPWhenExplicitlyEnabled() async {
        let connector = MockWebDAVConnector()
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "http://vault.local:8080/dav"
        viewModel.username = "alex"
        viewModel.password = "secret"
        viewModel.allowsUnencryptedHTTP = true

        let account = await viewModel.connect()

        XCTAssertNotNil(account)
        XCTAssertEqual(connector.connectCallCount, 1)
        XCTAssertEqual(connector.lastConfiguration?.serverURL, "http://vault.local:8080/dav")
        XCTAssertEqual(connector.lastConfiguration?.allowsUnencryptedHTTP, true)
    }

    func testConnectSuccessReturnsAccountAndClearsError() async {
        let connector = MockWebDAVConnector()
        let account = CloudAccount(
            id: "webdav-abc",
            displayName: "alex@cloud.example.com",
            provider: CloudProviderKind.webDAV.rawValue
        )
        connector.result = .success(account)
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "  https://cloud.example.com/  "
        viewModel.username = "  alex  "
        viewModel.password = "secret"

        let returned = await viewModel.connect()

        XCTAssertEqual(returned, account)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isConnecting)
        XCTAssertEqual(connector.connectCallCount, 1)
        XCTAssertEqual(connector.lastConfiguration?.serverURL, "https://cloud.example.com/")
        XCTAssertEqual(connector.lastConfiguration?.username, "alex")
        XCTAssertEqual(connector.lastConfiguration?.password, "secret")
        XCTAssertEqual(connector.lastConfiguration?.allowsUnencryptedHTTP, false)
    }

    func testConnectAuthenticationFailureUsesCredentialSpecificMessage() async {
        let connector = MockWebDAVConnector()
        connector.result = .failure(CloudProviderError.notAuthenticated)
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "https://cloud.example.com/"
        viewModel.username = "alex"
        viewModel.password = "secret"

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 1)
        XCTAssertEqual(
            viewModel.errorMessage,
            String(localized: "The WebDAV username or password was rejected.")
        )
        XCTAssertFalse(viewModel.isConnecting)
    }

    func testConnectFailureSetsErrorMessageAndClearsConnecting() async {
        let connector = MockWebDAVConnector()
        connector.result = .failure(CloudProviderError.fileNotFound)
        let viewModel = WebDAVConnectViewModel(connector: connector)
        viewModel.serverURL = "https://cloud.example.com/"
        viewModel.username = "alex"
        viewModel.password = "secret"

        let account = await viewModel.connect()

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 1)
        XCTAssertEqual(viewModel.errorMessage, CloudProviderError.fileNotFound.localizedDescription)
        XCTAssertFalse(viewModel.isConnecting)
    }

    // MARK: - signInWithNextcloud

    func testSignInWithNextcloudRejectsEmptyServerURLWithoutCallingCoordinator() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "   "

        let account = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertNil(account)
        XCTAssertEqual(nextcloudSignIn.signInCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSignInWithNextcloudRejectsHTTPServerURLUnlessExplicitlyAllowed() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "http://cloud.example.com"

        let account = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertNil(account)
        XCTAssertEqual(nextcloudSignIn.signInCallCount, 0)
        XCTAssertEqual(
            viewModel.errorMessage,
            String(localized: "Turn on Allow Unencrypted HTTP in Advanced to use an http:// server address.")
        )
    }

    func testSignInWithNextcloudNormalizesServerURLBeforeCallingCoordinator() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        nextcloudSignIn.result = .success(
            NextcloudLoginFlow.Credential(
                serverURL: URL(string: "https://cloud.example.com/")!,
                loginName: "alice",
                appPassword: "app-pw"
            )
        )
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "  https://cloud.example.com  "

        _ = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertEqual(nextcloudSignIn.lastServerURL, URL(string: "https://cloud.example.com/"))
    }

    func testSignInWithNextcloudSuccessBuildsWebDAVConfigurationAndCallsConnector() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        nextcloudSignIn.result = .success(
            NextcloudLoginFlow.Credential(
                serverURL: URL(string: "https://cloud.example.com/")!,
                loginName: "alice",
                appPassword: "app-pw-12345"
            )
        )
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "https://cloud.example.com"

        let account = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertNotNil(account)
        XCTAssertEqual(connector.connectCallCount, 1)
        XCTAssertEqual(connector.lastConfiguration?.serverURL, "https://cloud.example.com/remote.php/dav/files/alice/")
        XCTAssertEqual(connector.lastConfiguration?.username, "alice")
        XCTAssertEqual(connector.lastConfiguration?.password, "app-pw-12345")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isConnecting)
    }

    func testSignInWithNextcloudCancellationClearsErrorAndReturnsNil() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        nextcloudSignIn.result = .failure(CloudProviderError.authenticationCancelled)
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "https://cloud.example.com"

        let account = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertNil(account)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(connector.connectCallCount, 0)
    }

    func testSignInWithNextcloudFailureSurfacesErrorMessage() async {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        nextcloudSignIn.result = .failure(
            CloudProviderError.unknown("This doesn't look like a Nextcloud server. Check the server address.")
        )
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)
        viewModel.serverURL = "https://not-nextcloud.example.com"

        let account = await viewModel.signInWithNextcloud(presentationAnchor: Self.testAnchor)

        XCTAssertNil(account)
        XCTAssertEqual(connector.connectCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "This doesn't look like a Nextcloud server. Check the server address.")
    }

    func testCancelNextcloudSignInForwardsToCoordinator() {
        let connector = MockWebDAVConnector()
        let nextcloudSignIn = MockNextcloudSigningIn()
        let viewModel = WebDAVConnectViewModel(connector: connector, nextcloudSignIn: nextcloudSignIn)

        viewModel.cancelNextcloudSignIn()

        XCTAssertEqual(nextcloudSignIn.cancelCallCount, 1)
    }

    // MARK: - WebDAV URL construction from a Nextcloud credential

    func testWebDAVURLBuildsStandardNextcloudDavPath() {
        let url = WebDAVConnectViewModel.webDAVURL(
            server: URL(string: "https://cloud.example.com/")!,
            loginName: "alice"
        )

        XCTAssertEqual(url, URL(string: "https://cloud.example.com/remote.php/dav/files/alice/"))
    }

    func testWebDAVURLPercentEncodesLoginName() {
        let url = WebDAVConnectViewModel.webDAVURL(
            server: URL(string: "https://cloud.example.com/")!,
            loginName: "alice bob"
        )

        XCTAssertEqual(url, URL(string: "https://cloud.example.com/remote.php/dav/files/alice%20bob/"))
    }

    func testWebDAVURLHandlesServerInstalledUnderSubpath() {
        let url = WebDAVConnectViewModel.webDAVURL(
            server: URL(string: "https://example.com/nextcloud/")!,
            loginName: "alice"
        )

        XCTAssertEqual(url, URL(string: "https://example.com/nextcloud/remote.php/dav/files/alice/"))
    }

    @MainActor
    private static func testAnchor() -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

@MainActor
private final class MockNextcloudSigningIn: NextcloudSigningIn {
    var result: Result<NextcloudLoginFlow.Credential, Error> = .success(
        NextcloudLoginFlow.Credential(
            serverURL: URL(string: "https://cloud.example.com/")!,
            loginName: "alice",
            appPassword: "app-pw"
        )
    )
    private(set) var signInCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var lastServerURL: URL?

    func signIn(
        serverURL: URL,
        allowsUnencryptedHTTP: Bool,
        presentationAnchor: @escaping @MainActor () -> ASPresentationAnchor
    ) async throws -> NextcloudLoginFlow.Credential {
        signInCallCount += 1
        lastServerURL = serverURL
        return try result.get()
    }

    func cancel() {
        cancelCallCount += 1
    }
}

private final class MockWebDAVConnector: WebDAVConnecting, @unchecked Sendable {
    var result: Result<CloudAccount, Error> = .success(
        CloudAccount(id: "webdav-abc", displayName: "alex@cloud.example.com", provider: CloudProviderKind.webDAV.rawValue)
    )
    private(set) var connectCallCount = 0
    private(set) var lastConfiguration: WebDAVConnectionConfiguration?

    func connect(_ configuration: WebDAVConnectionConfiguration) async throws -> CloudAccount {
        connectCallCount += 1
        lastConfiguration = configuration
        return try result.get()
    }
}
