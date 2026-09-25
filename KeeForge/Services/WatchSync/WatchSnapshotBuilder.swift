import CryptoKit
import Foundation

/// Selects and decrypts the entries the Watch receives. Tags resolve the way
/// the tag index resolves them — the entry's own plus every ancestor group's —
/// so the Watch holds exactly what the tag browser lists under Apple Watch.
/// Recycle-bin contents never qualify.
enum WatchSnapshotBuilder {
    static func snapshot(
        root: KPGroup,
        databaseID: UUID,
        databaseName: String,
        sessionKey: SymmetricKey
    ) -> WatchVaultSnapshot {
        var entries: [WatchVaultSnapshot.Entry] = []

        func visit(_ group: KPGroup, inheritedTags: [String]) {
            guard group.id != root.recycleBinUUID else { return }
            let accumulatedTags = inheritedTags + group.tags
            for entry in group.entries {
                let tags = TagNormalizer.tags(from: entry.tags + accumulatedTags)
                guard tags.contains(where: WatchVaultSnapshot.isWatchTag) else { continue }
                entries.append(watchEntry(for: entry, sessionKey: sessionKey))
            }
            for child in group.groups {
                visit(child, inheritedTags: accumulatedTags)
            }
        }
        visit(root, inheritedTags: [])

        entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return WatchVaultSnapshot(databaseID: databaseID, databaseName: databaseName, entries: entries)
    }

    private static func watchEntry(for entry: KPEntry, sessionKey: SymmetricKey) -> WatchVaultSnapshot.Entry {
        let totp = entry.totpConfig.flatMap { config -> WatchVaultSnapshot.TOTP? in
            guard let resolved = TOTPGenerator.resolveSecret(config: config, sessionKey: sessionKey) else { return nil }
            return WatchVaultSnapshot.TOTP(
                secret: resolved.data,
                algorithm: config.algorithm,
                digits: config.digits,
                period: config.period
            )
        }
        return WatchVaultSnapshot.Entry(
            id: entry.id,
            title: entry.title,
            username: entry.username,
            password: (try? entry.password.decrypt(using: sessionKey)) ?? "",
            url: entry.url,
            notes: entry.notes,
            totp: totp
        )
    }
}
