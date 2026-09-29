# NextPass Browser Extension

Chromium (Manifest V3) extension for Brave and Chrome on macOS: a toolbar popup that lists the NextPass entries for the current site, searches the whole vault, and fills the login. It talks to the running NextPass Mac app on `127.0.0.1:19735`; the app accepts only requests carrying this extension's origin, holds the database, and decides what the extension may see. Design and rules: `../KeeForge/Services/BrowserBridge/AGENTS.md`.

## Set up (unpacked, for personal use)

1. In the browser: `brave://extensions` (or `chrome://extensions`), turn on Developer mode, **Load unpacked**, pick this folder. The ID must read `epimjjjokklkgjpjeceehckbmmppnmhd` (fixed by `key` in `manifest.json`) — NextPass accepts that origin only.
2. In NextPass: Settings ▸ AutoFill ▸ turn on **Allow Browser Extension** (off by default; NextPass does not listen otherwise).
3. With NextPass running, open the extension (toolbar icon or ⌘⇧L), choose **Connect to NextPass**, and allow it in NextPass only if its dialog shows the same code as the popup.

## Behavior

- Fills only frames on the page's own site (registrable domain via the Public Suffix List, so Apple's `idmsa.apple.com` sign-in frame fills on `account.apple.com`). When the login form comes from another site's frame (ID Austria loads it from `service.a-trust.at`), the popup names that site and fills there only after you allow it; the extension remembers that for the page's site only.
- **Password** asks NextPass to copy the password, so it gets the app's clipboard handling (hidden from clipboard managers, cleared after the timeout and on lock) and never passes through the browser. **User** copies the username directly.
- Permissions: `scripting` + access to all http(s) sites (fill the page and its embedded sign-in frames — the browser asks once, at install, like KeePassXC and Strongbox; no content scripts, so nothing runs in a page until you fill), `webNavigation` (the tab's real frame addresses — an iframe's `src` goes stale after a redirect, and filling frame by frame keeps one inaccessible frame from blocking the rest), `storage` (the pairing key and cross-site allowances), `127.0.0.1:19735` (NextPass).
- The popup's footer shows this browser's connection ID; NextPass lists the same ID beside the browser in Settings ▸ AutoFill, where each connected browser can be removed on its own.
- Stored in the extension (`chrome.storage.local`): its random pairing key and the cross-site frames you allowed.
- `vendor/tldts/` is [tldts](https://github.com/remusao/tldts) 7.4.16 (MIT), the Public Suffix List lookup, copied from the npm package's `dist/index.umd.min.js`.
- English only for now.
