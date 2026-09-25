import Foundation
import LocalAuthentication
import Observation
import os
import WatchConnectivity

/// Receives snapshots from the iPhone and keeps them in the Keychain so they
/// stay usable with the iPhone out of reach.
///
/// Plaintext lives in memory only while the app is active: `unload()` drops it
/// when the app leaves the foreground and `load()` reads it back.
@MainActor
@Observable
final class WatchVaultStore: NSObject {
    enum Availability: Equatable {
        case available
        case needsPasscode
    }

    private(set) var snapshots: [WatchVaultSnapshot] = []
    private(set) var availability: Availability = .available

    /// Messages that arrived while the Watch was locked, retried by `load()`.
    /// A transfer is consumed on delivery, so dropping one would lose the
    /// update until the iPhone next publishes.
    private var messagesAwaitingUnlock: [UUID: WatchSyncMessage] = [:]
    private var isInForeground = false

    private nonisolated static let logger = Logger(subsystem: "KeeForgeWatch", category: "Vault")

    func activate() {
        guard WCSession.isSupported(), WCSession.default.delegate == nil else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Keeps a WatchConnectivity background task alive until the session has
    /// delivered everything it was woken for.
    func receivePendingContent() async {
        activate()
        let session = WCSession.default
        let deadline = ContinuousClock.now + .seconds(20)
        while session.activationState != .activated || session.hasContentPending, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    func load() {
        isInForeground = true
        guard Self.hasPasscode() else {
            availability = .needsPasscode
            snapshots = []
            return
        }
        availability = .available

        let pending = messagesAwaitingUnlock.values
        messagesAwaitingUnlock.removeAll()
        pending.forEach(apply)

        do {
            snapshots = try WatchVaultKeychain.loadAll()
                .filter { $0.entries.isEmpty == false }
                .sorted { $0.databaseName.localizedStandardCompare($1.databaseName) == .orderedAscending }
        } catch {
            Self.logger.error("Could not read synced entries: \(String(describing: error), privacy: .public)")
        }
    }

    func unload() {
        isInForeground = false
        snapshots = []
    }

    private func receive(_ message: WatchSyncMessage) {
        apply(message)
        if isInForeground {
            load()
        }
    }

    private func apply(_ message: WatchSyncMessage) {
        do {
            switch message {
            case .snapshot(let snapshot) where snapshot.entries.isEmpty:
                try WatchVaultKeychain.delete(databaseID: snapshot.databaseID)
            case .snapshot(let snapshot):
                try WatchVaultKeychain.save(snapshot)
            case .removed(let databaseID):
                try WatchVaultKeychain.delete(databaseID: databaseID)
            }
        } catch WatchVaultKeychain.Failure.locked {
            messagesAwaitingUnlock[message.databaseID] = message
        } catch WatchVaultKeychain.Failure.noPasscode {
            Self.logger.error("Keychain refused synced entries: no passcode")
            availability = .needsPasscode
        } catch {
            Self.logger.error("Could not store synced entries: \(String(describing: error), privacy: .public)")
        }
    }

    private static func hasPasscode() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

extension WatchVaultStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Self.logger.error("Watch session activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let message = WatchSyncMessage(userInfo: userInfo) else { return }
        Task { @MainActor in
            self.receive(message)
        }
    }
}
