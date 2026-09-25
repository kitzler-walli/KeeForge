# Watch Sync Services

iPhone side of the Apple Watch companion (`../../../KeeForgeWatch/AGENTS.md`).

## Files

- `WatchVaultSnapshot.swift` — the wire model, compiled into the app and the Watch app: one database's `Apple Watch`-tagged entries in plaintext (title, username, password, URL, notes, decoded TOTP secret and parameters), plus `WatchSyncMessage`, the `transferUserInfo` envelope (`snapshot` or `removed`). Tag matching is case- and diacritic-insensitive.
- `WatchSnapshotBuilder.swift` — selects and decrypts the entries. Tags resolve like the tag index (own tags plus every ancestor group's); the Recycle Bin never qualifies. Pure; covered by `../../../KeeForgeTests/WatchSnapshotBuilderTests.swift`.
- `WatchSyncService.swift` (`#if os(iOS)`) — owns the `WCSession`. `DatabaseViewModel.publishUnlockedTree(root:)` calls `publish` at every point the AutoFill credential store refreshes (unlock, edit, save, merge, reload); `DatabaseListViewModel.removeDatabase` calls `remove`. The snapshot is built off the main thread. Nothing is queued unless a paired Watch has the app installed, and a newer snapshot cancels the outstanding transfer for the same database.

## Constraints

- `WatchVaultSnapshot.swift` must stay Foundation-only; the Watch target compiles it without the rest of the app.
- Not on the AutoFill allow-lists: the extension never publishes to the Watch.
- The snapshot carries plaintext secrets into the system's WatchConnectivity queue; that is accepted because the queue is only used when a Watch with the app is paired, and WatchConnectivity is encrypted between the paired devices.
