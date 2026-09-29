import SwiftUI

/// The Copy Username / Copy Password pair every entry row's context menu
/// offers. Shared by the iOS group list, the entry list behind search and the
/// tag browser, and the macOS rows, so the wording, the device-owner gate, and
/// the accessibility identifiers cannot drift per shell.
struct EntryRowCopyActions: View {
    let entry: KPEntry
    let viewModel: DatabaseViewModel

    var body: some View {
        if entry.username.isEmpty == false {
            Button("Copy Username") {
                Self.copyUsername(of: entry, viewModel: viewModel)
            }
            .accessibilityIdentifier("entry-row.copy-username-context")
        }

        if entry.hasPassword, viewModel.sessionKey != nil {
            Button("Copy Password") {
                Self.copyPassword(of: entry, viewModel: viewModel)
            }
            .accessibilityIdentifier("entry-row.copy-password-context")
        }
    }

    static func copyUsername(of entry: KPEntry, viewModel: DatabaseViewModel) {
        ClipboardService.copy(viewModel.resolvingFieldReferences(entry.username))
        viewModel.recordEntryCopy(.username, entryID: entry.id)
        HapticService.success()
    }

    /// The one password-copy path: this menu, the macOS Copy Password command,
    /// and ⌘C in a macOS entry list. Same device-owner gate as the detail
    /// view's copy button — biometrics when available, passcode / login
    /// password / Apple Watch otherwise, skipped when the user turned the
    /// setting off or the device has no protection.
    static func copyPassword(of entry: KPEntry, viewModel: DatabaseViewModel) {
        guard entry.hasPassword, viewModel.sessionKey != nil else { return }
        guard SettingsService.requireAuthenticationToCopyPasswords,
              BiometricService.canAuthenticateDeviceOwner else {
            performPasswordCopy(of: entry, viewModel: viewModel)
            return
        }

        Task { @MainActor in
            do {
                _ = try await BiometricService.authenticateDeviceOwner(
                    reason: String(localized: "Copy password")
                )
            } catch {
                return
            }
            performPasswordCopy(of: entry, viewModel: viewModel)
        }
    }

    private static func performPasswordCopy(of entry: KPEntry, viewModel: DatabaseViewModel) {
        ClipboardService.copy(viewModel.resolvedPassword(for: entry))
        viewModel.recordEntryCopy(.password, entryID: entry.id)
        HapticService.success()
    }
}
