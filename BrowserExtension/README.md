# NextPass Browser Extension

Chromium (Manifest V3) extension for Brave and Chrome on macOS: a toolbar popup that lists the NextPass entries for the current site, searches the whole vault, and fills the login. It talks to the running NextPass Mac app on `127.0.0.1:19735`; the app accepts only requests carrying this extension's origin, holds the database, and decides what the extension may see. Design and rules: `../KeeForge/Services/BrowserBridge/AGENTS.md`.

## Set up (unpacked, for personal use)

1. In the browser: `brave://extensions` (or `chrome://extensions`), turn on Developer mode, **Load unpacked**, pick this folder. The ID must read `epimjjjokklkgjpjeceehckbmmppnmhd` (fixed by `key` in `manifest.json`) — NextPass accepts that origin only.
2. With NextPass running, open the extension (toolbar icon or ⌘⇧L), choose **Connect to NextPass**, and allow it in NextPass.

## Behavior

- Fills only frames on the page's own host or a parent/subdomain of it. When the login form comes from another site's frame (ID Austria loads it from `service.a-trust.at`), the popup names that site and fills there only after you allow it; the browser then remembers that site permission.
- **Password** asks NextPass to copy the password, so it gets the app's clipboard handling (hidden from clipboard managers, cleared after the timeout and on lock) and never passes through the browser. **User** copies the username directly.
- Permissions: `activeTab` + `scripting` (fill the page you clicked the icon on), `webNavigation` (the tab's real frame addresses — an iframe's `src` goes stale after a redirect, and filling frame by frame keeps one inaccessible frame from blocking the rest), `storage` (the pairing key), `127.0.0.1:19735` (NextPass), and optional per-site `https://` access granted only when you allow a cross-site login frame.
- The only thing stored in the extension is its random pairing key (`chrome.storage.local`).
- English only for now.
