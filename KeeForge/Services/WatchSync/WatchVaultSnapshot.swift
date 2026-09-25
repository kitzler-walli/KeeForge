import Foundation

/// What the iPhone sends the Watch for one database: every entry carrying the
/// Apple Watch tag, in plaintext. Compiled into both the app and the Watch app,
/// so it stays Foundation-only.
struct WatchVaultSnapshot: Codable, Sendable, Equatable {
    static let tag = "Apple Watch"

    struct Entry: Codable, Sendable, Hashable, Identifiable {
        let id: UUID
        let title: String
        let username: String
        let password: String
        let url: String
        let notes: String
        let totp: TOTP?
    }

    struct TOTP: Codable, Sendable, Hashable {
        let secret: Data
        let algorithm: TOTPAlgorithm
        let digits: Int
        let period: Int
    }

    let databaseID: UUID
    let databaseName: String
    let entries: [Entry]

    static func isWatchTag(_ tag: String) -> Bool {
        tag.compare(Self.tag, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

/// The `transferUserInfo` envelope. A database with no tagged entries left is
/// sent as an empty snapshot; `removedDatabaseID` clears one the iPhone forgot.
enum WatchSyncMessage: Sendable {
    private static let snapshotKey = "snapshot"
    private static let removedDatabaseIDKey = "removedDatabaseID"

    case snapshot(WatchVaultSnapshot)
    case removed(databaseID: UUID)

    var databaseID: UUID {
        switch self {
        case .snapshot(let snapshot): snapshot.databaseID
        case .removed(let databaseID): databaseID
        }
    }

    func userInfo() throws -> [String: Any] {
        switch self {
        case .snapshot(let snapshot):
            [Self.snapshotKey: try JSONEncoder().encode(snapshot)]
        case .removed(let databaseID):
            [Self.removedDatabaseIDKey: databaseID.uuidString]
        }
    }

    init?(userInfo: [String: Any]) {
        if let data = userInfo[Self.snapshotKey] as? Data,
           let snapshot = try? JSONDecoder().decode(WatchVaultSnapshot.self, from: data) {
            self = .snapshot(snapshot)
        } else if let rawID = userInfo[Self.removedDatabaseIDKey] as? String,
                  let databaseID = UUID(uuidString: rawID) {
            self = .removed(databaseID: databaseID)
        } else {
            return nil
        }
    }
}
