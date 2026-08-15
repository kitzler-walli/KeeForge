import AuthenticationServices
import Foundation

/// Drives the WebDAV connect form: the manual server/username/password path,
/// and — when the server turns out to be Nextcloud — the browser-based Login
/// Flow v2 path. Both paths perform lightweight client-side validation and
/// hand a validated `WebDAVConnectionConfiguration` to the same
/// `WebDAVConnecting` provider, so a Nextcloud sign-in produces exactly the
/// same kind of `CloudAccount` the manual form does.
///
/// The password/app-password is never logged or included in any error
/// string; only the thrown error's `localizedDescription` is surfaced to the UI.
@MainActor
@Observable
final class WebDAVConnectViewModel {
    var serverURL = ""
    var username = ""
    var password = ""
    var allowsUnencryptedHTTP = false
    private(set) var isConnecting = false
    var errorMessage: String?

    private let connector: any WebDAVConnecting
    private let nextcloudSignIn: any NextcloudSigningIn

    init(connector: any WebDAVConnecting, nextcloudSignIn: any NextcloudSigningIn = NextcloudSignInCoordinator()) {
        self.connector = connector
        self.nextcloudSignIn = nextcloudSignIn
    }

    /// Attempts to connect using the current field values. Returns the created
    /// `CloudAccount` on success, or `nil` on validation/connection failure
    /// (with `errorMessage` set). The provider is never called when client-side
    /// validation fails.
    func connect() async -> CloudAccount? {
        guard isConnecting == false else { return nil }

        errorMessage = nil

        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedServerURL.isEmpty == false else {
            errorMessage = String(localized: "Enter the WebDAV server address.")
            return nil
        }

        guard trimmedUsername.isEmpty == false else {
            errorMessage = String(localized: "Enter your username.")
            return nil
        }

        guard password.isEmpty == false else {
            errorMessage = String(localized: "Enter your password.")
            return nil
        }

        let lowercasedServerURL = trimmedServerURL.lowercased()
        let usesHTTPS = lowercasedServerURL.hasPrefix("https://")
        let usesHTTP = lowercasedServerURL.hasPrefix("http://")

        guard usesHTTPS || (usesHTTP && allowsUnencryptedHTTP) else {
            if usesHTTP {
                errorMessage = String(localized: "Turn on Allow Unencrypted HTTP in Advanced to use an http:// server address.")
            } else {
                errorMessage = String(localized: "The server address must start with https://.")
            }
            return nil
        }

        isConnecting = true
        defer { isConnecting = false }

        let configuration = WebDAVConnectionConfiguration(
            serverURL: trimmedServerURL,
            username: trimmedUsername,
            password: password,
            allowsUnencryptedHTTP: allowsUnencryptedHTTP
        )

        do {
            return try await connector.connect(configuration)
        } catch {
            errorMessage = Self.connectionMessage(for: error)
            return nil
        }
    }

    /// Signs in to `serverURL` via Nextcloud Login Flow v2: opens the server's
    /// login page in a browser, waits for the user to approve access, and
    /// hands the resulting server-issued app password to the same
    /// `connector.connect(_:)` the manual form uses — the only difference is
    /// where the credential came from. Returns `nil` (with `errorMessage` set)
    /// on validation failure, a non-Nextcloud server, or a cancelled sign-in.
    func signInWithNextcloud(
        presentationAnchor: @escaping @MainActor () -> ASPresentationAnchor
    ) async -> CloudAccount? {
        guard isConnecting == false else { return nil }

        errorMessage = nil

        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedServerURL.isEmpty == false else {
            errorMessage = String(localized: "Enter the Nextcloud server address.")
            return nil
        }

        let normalizedServerURL: URL
        do {
            normalizedServerURL = try WebDAVURL.normalizedBaseURL(
                from: trimmedServerURL,
                allowsUnencryptedHTTP: allowsUnencryptedHTTP
            )
        } catch WebDAVURLError.insecureScheme {
            errorMessage = String(localized: "Turn on Allow Unencrypted HTTP in Advanced to use an http:// server address.")
            return nil
        } catch {
            errorMessage = String(localized: "The server address is not a valid URL.")
            return nil
        }

        isConnecting = true
        defer { isConnecting = false }

        do {
            let credential = try await nextcloudSignIn.signIn(
                serverURL: normalizedServerURL,
                allowsUnencryptedHTTP: allowsUnencryptedHTTP,
                presentationAnchor: presentationAnchor
            )
            let configuration = Self.configuration(for: credential, allowsUnencryptedHTTP: allowsUnencryptedHTTP)
            return try await connector.connect(configuration)
        } catch let cloudError as CloudProviderError where cloudError == .authenticationCancelled {
            return nil
        } catch {
            errorMessage = Self.connectionMessage(for: error)
            return nil
        }
    }

    /// Cancels an in-flight Nextcloud sign-in (e.g. the connect sheet was
    /// dismissed). A no-op if no sign-in is in flight.
    func cancelNextcloudSignIn() {
        nextcloudSignIn.cancel()
    }

    /// Builds the standard Nextcloud WebDAV endpoint
    /// (`{server}/remote.php/dav/files/{loginName}/`) from a Login Flow v2
    /// credential. The user only ever enters the bare Nextcloud server
    /// address — this is the one well-known path shape every Nextcloud
    /// server publishes, so there is nothing to ask them to type or guess.
    static func configuration(
        for credential: NextcloudLoginFlow.Credential,
        allowsUnencryptedHTTP: Bool
    ) -> WebDAVConnectionConfiguration {
        WebDAVConnectionConfiguration(
            serverURL: Self.webDAVURL(server: credential.serverURL, loginName: credential.loginName).absoluteString,
            username: credential.loginName,
            password: credential.appPassword,
            allowsUnencryptedHTTP: allowsUnencryptedHTTP
        )
    }

    static func webDAVURL(server: URL, loginName: String) -> URL {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else {
            return server
        }

        var path = components.percentEncodedPath
        if path.hasSuffix("/") == false {
            path += "/"
        }
        let encodedLoginName = loginName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? loginName
        components.percentEncodedPath = path + "remote.php/dav/files/\(encodedLoginName)/"
        return components.url ?? server
    }

    private static func connectionMessage(for error: Error) -> String {
        if let cloudError = error as? CloudProviderError, cloudError == .notAuthenticated {
            return String(localized: "The WebDAV username or password was rejected.")
        }

        return error.localizedDescription
    }
}
