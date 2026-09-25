# Apple Watch App

The `KeeForgeWatch` target: a watchOS companion that shows the entries tagged `Apple Watch` in the iPhone app and computes their TOTP codes on the Watch, so codes keep working with the iPhone lost, off, or out of range. It is embedded in the iOS app (`project.yml` → `KeeForge` dependency, "Embed Watch Content") and ships in lockstep with it: same `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.

## Files

- `NextPassWatchApp.swift` — app entry. Loads secrets into memory when the scene is active or inactive and drops them in the background; `.backgroundTask(.watchConnectivity)` lets watchOS wake the app to store a transfer before it is next opened.
- `WatchVaultStore.swift` — receives `WatchSyncMessage`s over WatchConnectivity (`transferUserInfo`, sent by `../KeeForge/Services/WatchSync/WatchSyncService.swift`), writes them through `WatchVaultKeychain`, and serves the list. A message that arrives while the Watch is locked is held in memory and applied on the next `load()`. An empty snapshot or a `removed` message deletes that database's item.
- `WatchVaultKeychain.swift` — one generic-password item per database (service `at.kw.nextpass.watch.vault`, account = database UUID), `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`: never backed up or migrated, readable only while the Watch is unlocked, impossible without a Watch passcode (the app then shows Passcode Required and stores nothing).
- `VaultListView.swift`, `WatchEntryDetailView.swift` — list (sectioned by database once there is more than one) and detail: TOTP code with countdown, username, password (tap to reveal), website, notes. Codes and the password are `.privacySensitive()`, so the always-on display redacts them.
- `Localizable.xcstrings` — the Watch's own catalog; gated by `KeeForgeTests/LocalizationTests.swift` like the four app catalogs.

## Constraints

- The target compiles exactly two shared files: `../KeeForge/Models/TOTPCode.swift` (RFC 6238 math, also behind `TOTPGenerator`) and `../KeeForge/Services/WatchSync/WatchVaultSnapshot.swift` (the wire model). Keep both Foundation/CryptoKit-only; nothing from the KDBX stack belongs on the Watch.
- The Watch never sees the database or its master key — only the plaintext fields of tagged entries, which is the product decision: a stolen Watch is protected by its passcode and wrist detection, not by NextPass.
- Synced data does not expire. It changes only when the iPhone publishes (unlock, edit, save, merge, reload of that database) or the database is removed from the iPhone's list.

## Testing

- `../KeeForgeTests/WatchSnapshotBuilderTests.swift` covers what the iPhone selects and sends.
- `../KeeForgeWatchUITests/WatchOfflineTOTPUITests.swift` is opt-in (`TEST_RUNNER_WATCH_E2E_EXPECT_SYNC=1`): after `NextcloudLoginFlowE2EUITests` has synced its `Watch E2E` entry, it checks the Watch's code against an independent RFC 6238 computation plus the username and password, with the iPhone switched off.
- **Simulator limitation:** paired iPhone/Watch simulators deliver `updateApplicationContext` but silently drop `transferUserInfo` (verified: identical payloads, only the context arrived). The end-to-end sync therefore needs a real iPhone + Apple Watch pair; the Watch test above can still run in the simulator once the entry is on the Watch.
