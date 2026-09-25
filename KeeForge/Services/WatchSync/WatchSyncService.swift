#if os(iOS)
import CryptoKit
import Foundation
import os
import WatchConnectivity

/// Pushes Apple Watch–tagged entries to the Watch app over WatchConnectivity.
///
/// `transferUserInfo` rather than the application context: each database is a
/// separate queued message, and queued transfers survive the Watch being out
/// of range until it next connects. Superseded transfers for the same database
/// are cancelled before a new one is queued, so the queue holds at most one
/// snapshot per database. Nothing is queued unless a paired Watch has the app
/// installed, which keeps plaintext out of the system queue for everyone else.
@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    private nonisolated static let logger = Logger(subsystem: "KeeForge", category: "WatchSync")

    private var session: WCSession?
    private var messagesAwaitingActivation: [UUID: WatchSyncMessage] = [:]

    var isWatchAppInstalled: Bool {
        guard let session, session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    func activate() {
        guard session == nil, WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Builds and queues the snapshot off the main thread; decrypting every
    /// tagged entry is secret handling.
    func publish(root: KPGroup, databaseID: UUID, databaseName: String, sessionKey: SymmetricKey) {
        guard session != nil else { return }
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                WatchSnapshotBuilder.snapshot(
                    root: root,
                    databaseID: databaseID,
                    databaseName: databaseName,
                    sessionKey: sessionKey
                )
            }.value
            send(.snapshot(snapshot))
        }
    }

    func remove(databaseID: UUID) {
        send(.removed(databaseID: databaseID))
    }

    private func send(_ message: WatchSyncMessage) {
        guard let session else { return }
        guard session.activationState == .activated else {
            messagesAwaitingActivation[message.databaseID] = message
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        for transfer in session.outstandingUserInfoTransfers
        where WatchSyncMessage(userInfo: transfer.userInfo)?.databaseID == message.databaseID {
            transfer.cancel()
        }
        do {
            session.transferUserInfo(try message.userInfo())
        } catch {
            Self.logger.error("Could not encode a Watch snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func flushMessagesAwaitingActivation() {
        let pending = messagesAwaitingActivation.values
        messagesAwaitingActivation.removeAll()
        pending.forEach(send)
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Self.logger.error("Watch session activation failed: \(error.localizedDescription, privacy: .public)")
        }
        Task { @MainActor in
            self.flushMessagesAwaitingActivation()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Switching to another paired Watch deactivates the session; activating
    /// again binds it to the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
