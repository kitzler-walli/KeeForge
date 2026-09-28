#if os(macOS)
import AppKit
import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import os
import SwiftUI

/// Strongbox-style Touch ID for the Mac unlock screen: an `LAAuthenticationView`
/// that waits for a finger while NextPass is frontmost, with no system alert.
///
/// Listening is armed only while the app is active. Resigning invalidates the
/// context, which frees the sensor and keeps a backgrounded NextPass from taking
/// a touch meant for another app; every return re-arms it. The evaluation runs
/// while the database is still `.locked`, so the icon stays on screen, and only a
/// recognized finger moves on to the keychain read
/// (`DatabaseViewModel.unlock(withAuthenticatedBiometrics:)`).
@MainActor
@Observable
final class MacInlineTouchIDSession {
    enum Phase: Equatable {
        case idle
        case listening
        /// Touch ID stopped on its own (unrecognized finger, lockout); the user
        /// re-arms it with Try Again or Return.
        case stopped(message: String)
    }

    /// Set once LocalAuthentication refuses the inline view (macOS 27 answers
    /// -1007 "Caller is not Apple signed" for some signing identities); the
    /// unlock screen then keeps the standard Touch ID button for this launch.
    private(set) static var isUnsupported = false

    private(set) var phase: Phase = .idle
    /// Observable mirror of `isUnsupported` for the view that hosts the icon.
    private(set) var usesInlineView = !MacInlineTouchIDSession.isUnsupported
    private(set) var authenticationView: LAAuthenticationView?
    private var context: LAContext?

    private static let logger = Logger(subsystem: "NextPass", category: "InlineTouchID")

    var isListening: Bool { phase == .listening }

    func arm(viewModel: DatabaseViewModel) {
        guard usesInlineView,
              NSApplication.shared.isActive,
              phase != .listening,
              case .locked = viewModel.state,
              viewModel.canUseBiometrics else { return }

        let context = LAContext()
        // Pairing happens at init: the view must exist before evaluation starts
        // or LocalAuthentication falls back to its standard alert.
        let view = LAAuthenticationView(context: context, controlSize: .regular)
        self.context = context
        authenticationView = view
        phase = .listening

        Task {
            do {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: String(localized: "Unlock your password database")
                )
                guard self.context === context else { return }
                // Hand the evaluated context to the keychain read; invalidating
                // it now would fail that read.
                self.context = nil
                phase = .idle
                _ = await viewModel.unlock(withAuthenticatedBiometrics: AuthenticatedBiometricContext(context: context))
            } catch {
                guard self.context === context else { return }
                self.context = nil
                handle(error)
            }
        }
    }

    func disarm() {
        guard phase == .listening else { return }
        context?.invalidate()
        context = nil
        phase = .idle
    }

    private func handle(_ error: Error) {
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain else {
            phase = .idle
            return
        }
        switch LAError.Code(rawValue: nsError.code) {
        case .appCancel, .systemCancel, .userCancel, .notInteractive:
            phase = .idle
        case .authenticationFailed:
            phase = .stopped(message: String(localized: "Touch ID didn't recognize this finger."))
        case .biometryLockout:
            phase = .stopped(message: String(localized: "Touch ID is locked. Enter your password to unlock."))
        default:
            Self.logger.error("Inline Touch ID unavailable: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            Self.isUnsupported = true
            usesInlineView = false
            authenticationView = nil
            phase = .idle
        }
    }
}

/// Hosts the session's current `LAAuthenticationView`; a fresh view is paired
/// with every armed context, so the host swaps its subview when that changes.
/// The system decides the glyph's size per control size, so layout asks the
/// view instead of imposing a frame it would draw past.
struct MacInlineTouchIDIcon: NSViewRepresentable {
    let authenticationView: LAAuthenticationView?

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard container.subviews.first !== authenticationView else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        guard let authenticationView else { return }
        authenticationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(authenticationView)
        NSLayoutConstraint.activate([
            authenticationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            authenticationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            authenticationView.topAnchor.constraint(equalTo: container.topAnchor),
            authenticationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        authenticationView?.fittingSize
    }
}
#endif
