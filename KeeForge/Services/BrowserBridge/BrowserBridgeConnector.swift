#if os(macOS)
import AppKit
import Foundation

/// The app-side user interface of the browser bridge: approving a new browser
/// and coming forward to be unlocked.
@MainActor
enum BrowserBridgeConnector {
    /// The NextPass extension's ID, fixed by the public `key` in
    /// `BrowserExtension/manifest.json`; `BrowserBridgeServer` accepts requests
    /// from this origin only.
    static let extensionID = "epimjjjokklkgjpjeceehckbmmppnmhd"

    /// Posted by Settings when "Allow Browser Extension" changes, so the app
    /// starts or stops listening right away.
    static let settingDidChangeNotification = Notification.Name("KeeForge.browserExtensionSettingDidChange")

    /// The code is the one the extension's popup shows: only the extension
    /// the user is looking at can raise a prompt they will match.
    static func approvePairing(browserName: String, code: String) async -> Bool {
        NSApp.activate()
        let spacedCode = "\(code.prefix(3)) \(code.suffix(3))"
        let alert = NSAlert()
        alert.messageText = String(localized: "Allow \(browserName) to use NextPass?")
        alert.informativeText = String(localized: "Only allow this if the NextPass extension in \(browserName) shows the code \(spacedCode). It will then be able to search your unlocked database and fill passwords into web pages.")
        alert.addButton(withTitle: String(localized: "Allow"))
        alert.addButton(withTitle: String(localized: "Don't Allow"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Brings NextPass to the front — reopening its window if it was closed —
    /// so the unlock screen's Touch ID can take the user's finger.
    static func presentForUnlock() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in }
    }
}
#endif
