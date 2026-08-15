import AuthenticationServices
import Foundation

/// The in-app connection seam used by the Nextcloud browser sign-in flow.
/// Kept separate from the concrete `ASWebAuthenticationSession`-driving
/// implementation so `WebDAVConnectViewModel` can be unit-tested without a
/// live browser session — mirrors `WebDAVConnecting`'s role for the manual
/// connect form.
@MainActor
protocol NextcloudSigningIn {
    func signIn(
        serverURL: URL,
        allowsUnencryptedHTTP: Bool,
        presentationAnchor: @escaping @MainActor () -> ASPresentationAnchor
    ) async throws -> NextcloudLoginFlow.Credential

    func cancel()
}

/// Drives the browser half of Nextcloud Login Flow v2.
///
/// Nextcloud's login page never redirects back into the app — it just shows
/// an "you may close this window" page after the user grants access — so the
/// `ASWebAuthenticationSession` here is used purely for its system-browser
/// presentation, not for its callback-URL completion mechanism. Completion is
/// instead driven by polling (`NextcloudLoginFlow.pollUntilComplete`) running
/// concurrently: whichever finishes first — polling succeeds, the user
/// dismisses the browser sheet, or the token expires — resolves the flow
/// exactly once, and `finish(_:)` tears the other side down.
@MainActor
final class NextcloudSignInCoordinator: NSObject, NextcloudSigningIn {
    /// `ASWebAuthenticationSession` requires a callback URL scheme even
    /// though this flow never uses one — Nextcloud's login page never
    /// navigates to it. The value only needs to be syntactically valid.
    private static let unusedCallbackScheme = "nextpass-webauth-unused"

    private let loginFlow: NextcloudLoginFlow

    private var session: ASWebAuthenticationSession?
    private var pollTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<NextcloudLoginFlow.Credential, Error>?
    private var presentationAnchorProvider: (@MainActor () -> ASPresentationAnchor)?

    init(loginFlow: NextcloudLoginFlow = NextcloudLoginFlow()) {
        self.loginFlow = loginFlow
    }

    /// Starts the flow: initiates against `serverURL`, opens the login page
    /// in a system browser, and polls until Nextcloud hands back a
    /// credential. Only one sign-in can be in flight at a time.
    func signIn(
        serverURL: URL,
        allowsUnencryptedHTTP: Bool,
        presentationAnchor: @escaping @MainActor () -> ASPresentationAnchor
    ) async throws -> NextcloudLoginFlow.Credential {
        guard continuation == nil else {
            throw CloudProviderError.unknown(String(localized: "A Nextcloud sign-in is already in progress."))
        }

        let initiateResult = try await loginFlow.initiate(serverURL: serverURL)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.presentationAnchorProvider = presentationAnchor

            let session = ASWebAuthenticationSession(
                url: initiateResult.loginURL,
                callbackURLScheme: Self.unusedCallbackScheme
            ) { [weak self] _, error in
                Task { @MainActor in
                    self?.handleSessionCompletion(error: error)
                }
            }
            session.presentationContextProvider = self
            // Deliberately shares the system browser's cookie jar: a user
            // already signed in to Nextcloud in Safari can approve access
            // without re-entering credentials.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            pollTask = Task { [weak self] in
                await self?.pollAndResolve(
                    endpoint: initiateResult.pollEndpoint,
                    token: initiateResult.pollToken,
                    allowsUnencryptedHTTP: allowsUnencryptedHTTP
                )
            }

            guard session.start() else {
                finish(.failure(CloudProviderError.unknown(String(localized: "Could not open the sign-in page."))))
                return
            }
        }
    }

    /// Cancels an in-flight sign-in (e.g. the view hosting it was dismissed).
    /// A no-op if nothing is in flight.
    func cancel() {
        finish(.failure(CloudProviderError.authenticationCancelled))
    }

    private func pollAndResolve(endpoint: URL, token: String, allowsUnencryptedHTTP: Bool) async {
        do {
            let credential = try await loginFlow.pollUntilComplete(
                endpoint: endpoint,
                token: token,
                allowsUnencryptedHTTP: allowsUnencryptedHTTP
            )
            finish(.success(credential))
        } catch is CancellationError {
            // The flow was already resolved elsewhere; nothing left to do.
        } catch {
            finish(.failure(error))
        }
    }

    /// Reached both when the user dismisses the browser sheet themselves and
    /// (harmlessly, as a no-op) when `finish(_:)` cancels the session after a
    /// poll-driven resolution — `finish` clears `continuation` before calling
    /// `session.cancel()`, so only a genuine user-initiated dismissal reaches
    /// the `finish` call below.
    private func handleSessionCompletion(error: Error?) {
        guard continuation != nil else { return }
        finish(.failure(CloudProviderError.authenticationCancelled))
    }

    /// Resolves the continuation exactly once and tears down the session/poll
    /// task. `continuation` is cleared *before* cancelling the session so the
    /// resulting re-entrant `handleSessionCompletion` call sees a already-nil
    /// continuation and no-ops instead of overwriting this result.
    private func finish(_ result: Result<NextcloudLoginFlow.Credential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        presentationAnchorProvider = nil

        let sessionToCancel = session
        session = nil
        pollTask?.cancel()
        pollTask = nil

        sessionToCancel?.cancel()
        continuation.resume(with: result)
    }
}

extension NextcloudSignInCoordinator: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presentationAnchorProvider?() ?? ASPresentationAnchor()
        }
    }
}
