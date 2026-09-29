# Browser Bridge

macOS only. Connects the NextPass browser extension (`../../../BrowserExtension/`, Chromium Manifest V3 — Brave and Chrome) to the running app, so the extension can search the unlocked database and fill a login without ever holding the database or its key. Nothing is installed in the browser beyond the extension itself.

## Path of a request

extension popup → `fetch` `POST http://127.0.0.1:19735/` (one JSON message) → `BrowserBridgeServer` (Network.framework listener bound to loopback) → origin check → `BrowserBridgeRequestHandler` on the main actor → the active `DatabaseViewModel` (`BrowserBridgeVault`).

## Files

- `BrowserBridgeServer.swift` — the loopback listener and `BrowserBridgeHTTP`, just enough HTTP/1.1 for one request per connection (64 KB cap). A client gets `requestTimeout` (5 s) to deliver its request — only receiving is timed, since a `pair` answer waits for the user's click — and at most `maxConnections` (8) are served at once, so a local process cannot exhaust the app's file descriptors. Started and stopped by the "Allow Browser Extension" setting (`SettingsService.browserExtensionEnabled`, default off; `BrowserBridgeConnector.settingDidChangeNotification`). A request whose `Origin` is not `chrome-extension://<BrowserBridgeConnector.extensionID>` gets 403 before the handler sees it: the browser sets that header for extension requests and no web page can forge it.
- `BrowserBridgeRequestHandler.swift` — actions `status`, `pair`, `unlock`, `search`, `credentials`, `copyPassword` (the app's `ClipboardService` copies it — concealed, timed clear, clear on lock — so it never reaches the browser); `BrowserBridgePairingStore` (SHA-256 hashes of each extension's random 32-byte key, as Keychain items in NextPass's access group — not `UserDefaults`, whose plist any process running as the user can edit to approve itself; each item's label is the browser name the extension reports (e.g. "Brave (Chromium 140)"), its creation date the pairing time, and `kSecAttrGeneric` the last use, written at most once per `useRecordingInterval`. Settings lists them with the first four hex digits of the key hash as an ID — the popup's footer shows the same ID — and a per-browser Remove); `DatabaseViewModel`'s `BrowserBridgeVault` conformance (entries = `credentialStoreEntries`, i.e. exactly what AutoFill offers).
- `BrowserBridgeConnector.swift` — the extension ID, the pairing approval alert, and bringing the app forward (reopening its window) so the user can unlock with Touch ID.

## Rules

- Only `status` and `pair` work unpaired, and unpaired `status` says nothing about the vault — not the name, not whether it is unlocked. Pairing needs the user's click in NextPass on a dialog showing the 6-digit code the popup displays, so a prompt raised by anything but the extension on screen cannot be matched; one prompt at a time (`busy`), at most `maxPairingPrompts` per `pairingWindow` (`tooManyAttempts`).
- Secrets leave only through `credentials`, for one entry, while the vault is unlocked; search results carry title, user name, and URL.
- The extension fills only frames on the page's own site — its registrable domain, from the Public Suffix List (vendored `tldts`), so `idmsa.apple.com` counts for `account.apple.com` but `a.github.io` never for `b.github.io` — plus sites the user explicitly allowed in the popup when a login form lives in another site's frame (ID Austria loads it from `service.a-trust.at`). The allowance is kept per page site (`siteGrants` in `chrome.storage.local`), so it never fills that frame on another site. The extension holds host access to all http(s) sites from install, because the browser cannot inject into a cross-origin frame otherwise; it declares no content scripts, so it touches a page only when the user fills.
- A served vault request (`search`, `credentials`, `copyPassword`) calls `noteBridgeActivity()`, which restarts the auto-lock timer: using the extension is using NextPass. `status` polls do not, so an idle popup cannot keep the vault open.
- The port is fixed (`BrowserBridgeServer.port`, mirrored in `popup.js` and the manifest's `host_permissions`); the extension cannot start NextPass, it needs the app running.
- The listener needs `com.apple.security.network.server`, in both Mac entitlements files; it binds 127.0.0.1 only.
- The extension ID is fixed by the public `key` in the extension manifest. The private key was not kept (it only packs a .crx for a store listing).
- Covered by `../../../KeeForgeTests/BrowserBridgeTests.swift` (`KeeForgeMacTests`).
