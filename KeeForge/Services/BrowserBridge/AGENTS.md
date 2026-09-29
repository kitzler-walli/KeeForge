# Browser Bridge

macOS only. Connects the NextPass browser extension (`../../../BrowserExtension/`, Chromium Manifest V3 — Brave and Chrome) to the running app, so the extension can search the unlocked database and fill a login without ever holding the database or its key. Nothing is installed in the browser beyond the extension itself.

## Path of a request

extension popup → `fetch` `POST http://127.0.0.1:19735/` (one JSON message) → `BrowserBridgeServer` (Network.framework listener bound to loopback) → origin check → `BrowserBridgeRequestHandler` on the main actor → the active `DatabaseViewModel` (`BrowserBridgeVault`).

## Files

- `BrowserBridgeServer.swift` — the loopback listener and `BrowserBridgeHTTP`, just enough HTTP/1.1 for one request per connection (64 KB cap). A request whose `Origin` is not `chrome-extension://<BrowserBridgeConnector.extensionID>` gets 403 before the handler sees it: the browser sets that header for extension requests and no web page can forge it.
- `BrowserBridgeRequestHandler.swift` — actions `status`, `pair`, `unlock`, `search`, `credentials`, `copyPassword` (the app's `ClipboardService` copies it — concealed, timed clear, clear on lock — so it never reaches the browser); `BrowserBridgePairingStore` (SHA-256 hashes of each extension's random 32-byte key, app-local `UserDefaults`); `DatabaseViewModel`'s `BrowserBridgeVault` conformance (entries = `credentialStoreEntries`, i.e. exactly what AutoFill offers).
- `BrowserBridgeConnector.swift` — the extension ID, the pairing approval alert, and bringing the app forward (reopening its window) so the user can unlock with Touch ID.

## Rules

- Only `status` and `pair` work unpaired, and `status` withholds the database name until paired. Pairing always needs the user's click in NextPass.
- Secrets leave only through `credentials`, for one entry, while the vault is unlocked; search results carry title, user name, and URL.
- The extension fills only frames on the page's own site, plus sites the user explicitly allowed when a login form lives in another site's frame (ID Austria loads it from `service.a-trust.at`); that consent is the browser's own per-site host permission (`optional_host_permissions`).
- A served vault request (`search`, `credentials`, `copyPassword`) calls `noteBridgeActivity()`, which restarts the auto-lock timer: using the extension is using NextPass. `status` polls do not, so an idle popup cannot keep the vault open.
- The port is fixed (`BrowserBridgeServer.port`, mirrored in `popup.js` and the manifest's `host_permissions`); the extension cannot start NextPass, it needs the app running.
- The listener needs `com.apple.security.network.server`, in both Mac entitlements files; it binds 127.0.0.1 only.
- The extension ID is fixed by the public `key` in the extension manifest. The private key was not kept (it only packs a .crx for a store listing).
- Covered by `../../../KeeForgeTests/BrowserBridgeTests.swift` (`KeeForgeMacTests`).
