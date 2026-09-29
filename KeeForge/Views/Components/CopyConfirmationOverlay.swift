import SwiftUI

/// Covers a copyable field with a green "Copied to Clipboard" banner for a
/// moment after each copy. `trigger` changes once per copy; `onChange`, not
/// `task(id:)`, so a row that appears after an earlier copy stays quiet.
struct CopyConfirmationOverlay<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @State private var isShowing = false
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green)
                        .overlay {
                            Label("Copied to Clipboard", systemImage: "checkmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(-4)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .accessibilityIdentifier("copy-confirmation")
                }
            }
            .onChange(of: trigger) { _, _ in
                show()
            }
            .onDisappear {
                hideTask?.cancel()
            }
    }

    private func show() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { isShowing = true }
        AccessibilityNotification.Announcement(String(localized: "Copied to Clipboard")).post()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeIn(duration: 0.25)) { isShowing = false }
        }
    }
}

extension View {
    func copyConfirmation(trigger: some Equatable) -> some View {
        modifier(CopyConfirmationOverlay(trigger: trigger))
    }
}
