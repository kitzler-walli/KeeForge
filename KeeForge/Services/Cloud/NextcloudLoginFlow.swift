import Foundation

/// Nextcloud "Login Flow v2": a browser-based sign-in that hands back a
/// server-issued app password without the user ever typing one in.
///
/// The caller opens `initiate(serverURL:).loginURL` in a system browser
/// (`ASWebAuthenticationSession`, not a `WKWebView` — Nextcloud's own iOS team
/// found embedded web views can't complete passkey/2FA logins), then polls
/// `poll(endpoint:token:)` — or drives the loop with `pollUntilComplete` —
/// until Nextcloud returns the resulting WebDAV credential. The credential is
/// a normal Nextcloud app password under the hood, just issued through the
/// browser instead of pasted in by hand; `userAgent` becomes its label in the
/// user's Nextcloud Security settings, so it should identify this app/device.
///
/// https://docs.nextcloud.com/server/latest/developer_manual/client_apis/LoginFlow/index.html
struct NextcloudLoginFlow: Sendable {
    /// Label Nextcloud shows for the app password this flow creates, in
    /// Security settings → Devices, so the user can recognize and revoke it.
    static let defaultUserAgent = "NextPass"

    /// Nextcloud's own token lifetime (20 minutes) — the server never signals
    /// expiry explicitly (a stale token just keeps answering 404, the same as
    /// "not finished yet"), so the deadline has to be enforced client-side.
    static let tokenLifetime: Duration = .seconds(20 * 60)

    private let transport: WebDAVClient.Transport
    private let userAgent: String

    init(
        transport: @escaping WebDAVClient.Transport = WebDAVClient.liveTransport(),
        userAgent: String = Self.defaultUserAgent
    ) {
        self.transport = transport
        self.userAgent = userAgent
    }

    struct InitiateResult: Sendable, Equatable {
        let loginURL: URL
        let pollToken: String
        let pollEndpoint: URL
    }

    struct Credential: Sendable, Equatable {
        let serverURL: URL
        let loginName: String
        let appPassword: String
    }

    // MARK: - Initiate

    /// POSTs to `{server}/index.php/login/v2` to start a flow. `serverURL`
    /// must already be normalized (see `WebDAVURL.normalizedBaseURL`) — the
    /// documented `index.php` path is used unconditionally because it works
    /// whether or not the server has "pretty URL" rewriting enabled.
    func initiate(serverURL: URL) async throws -> InitiateResult {
        guard let requestURL = URL(string: "index.php/login/v2", relativeTo: serverURL) else {
            throw CloudProviderError.unknown(String(localized: "The server address is not a valid URL."))
        }

        let (data, statusCode) = try await send(url: requestURL)
        guard statusCode == 200 else {
            throw Self.initiateError(for: statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(InitiateResponse.self, from: data),
              let loginURL = URL(string: decoded.login),
              let pollEndpoint = URL(string: decoded.poll.endpoint),
              decoded.poll.token.isEmpty == false else {
            throw Self.malformedResponseError()
        }

        return InitiateResult(loginURL: loginURL, pollToken: decoded.poll.token, pollEndpoint: pollEndpoint)
    }

    // MARK: - Poll

    /// Polls once. Nextcloud answers 404 while the user hasn't finished in
    /// the browser yet — that's the expected steady state, not an error, so
    /// it returns `nil` rather than throwing. The eventual 200 is sent
    /// exactly once; callers must not poll again after a non-nil result.
    func poll(endpoint: URL, token: String, allowsUnencryptedHTTP: Bool = false) async throws -> Credential? {
        let body = "token=\(token)".data(using: .utf8)
        let (data, statusCode) = try await send(url: endpoint, body: body)

        if statusCode == 404 {
            return nil
        }
        guard statusCode == 200 else {
            throw Self.pollError(for: statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(PollResponse.self, from: data),
              let serverURL = try? WebDAVURL.normalizedBaseURL(
                  from: decoded.server,
                  allowsUnencryptedHTTP: allowsUnencryptedHTTP
              ),
              decoded.loginName.isEmpty == false,
              decoded.appPassword.isEmpty == false else {
            throw Self.malformedResponseError()
        }

        return Credential(serverURL: serverURL, loginName: decoded.loginName, appPassword: decoded.appPassword)
    }

    /// Polls at `interval` until a credential arrives or `tokenLifetime`
    /// elapses. Cooperative cancellation (e.g. the user dismissed the browser
    /// sheet) stops the loop the next time it checks or sleeps.
    func pollUntilComplete(
        endpoint: URL,
        token: String,
        allowsUnencryptedHTTP: Bool = false,
        interval: Duration = .seconds(1),
        timeout: Duration = Self.tokenLifetime
    ) async throws -> Credential {
        let deadline = ContinuousClock.now + timeout
        while true {
            try Task.checkCancellation()

            if let credential = try await poll(endpoint: endpoint, token: token, allowsUnencryptedHTTP: allowsUnencryptedHTTP) {
                return credential
            }
            guard ContinuousClock.now < deadline else {
                throw CloudProviderError.unknown(String(localized: "This sign-in link expired. Try connecting again."))
            }
            try await Task.sleep(for: interval)
        }
    }

    // MARK: - Transport

    private func send(url: URL, body: Data? = nil) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        do {
            let (data, httpResponse) = try await transport(request)
            return (data, httpResponse.statusCode)
        } catch let error as CloudProviderError {
            throw error
        } catch let urlError as URLError {
            throw WebDAVClient.mapURLError(urlError)
        } catch {
            throw CloudProviderError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Error mapping

    private static func initiateError(for statusCode: Int) -> CloudProviderError {
        switch statusCode {
        case 404:
            .unknown(String(localized: "This doesn't look like a Nextcloud server. Check the server address."))
        case 401, 403:
            .unknown(String(localized: "The server refused the sign-in request."))
        case 500 ... 599:
            .unknown(String(localized: "The server reported an error (HTTP \(statusCode)). Try again shortly."))
        default:
            .unknown(String(localized: "The server returned an unexpected response (HTTP \(statusCode))."))
        }
    }

    private static func pollError(for statusCode: Int) -> CloudProviderError {
        switch statusCode {
        case 500 ... 599:
            .unknown(String(localized: "The server reported an error (HTTP \(statusCode)). Try again shortly."))
        default:
            .unknown(String(localized: "The server returned an unexpected response (HTTP \(statusCode))."))
        }
    }

    private static func malformedResponseError() -> CloudProviderError {
        .unknown(String(localized: "The server's sign-in response was not understood."))
    }

    // MARK: - Wire format

    private struct InitiateResponse: Decodable {
        struct Poll: Decodable {
            let token: String
            let endpoint: String
        }

        let poll: Poll
        let login: String
    }

    private struct PollResponse: Decodable {
        let server: String
        let loginName: String
        let appPassword: String
    }
}
