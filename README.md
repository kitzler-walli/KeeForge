<p align="center">
  <img src=".github/assets/NextPass-icon-1024.png" alt="NextPass app icon" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  English | <a href="docs/i18n/README.de.md">Deutsch</a> | <a href="docs/i18n/README.fr.md">Français</a> | <a href="docs/i18n/README.es.md">Español</a> | <a href="docs/i18n/README.zh-Hans.md">简体中文</a> | <a href="docs/i18n/README.zh-Hant.md">繁體中文</a> | <a href="docs/i18n/README.ja.md">日本語</a>
</p>

<p align="center">
  A free, open-source KeePass manager for iPhone, iPad, Mac, and Apple Watch.
  <br />
  Native SwiftUI, local-first storage, AutoFill, passkeys, TOTP, Nextcloud and WebDAV sync, and a browser extension for Brave and Chrome.
</p>

<p align="center">
  <img alt="Requires iOS 18.0 or later" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="Requires macOS 15.0 or later" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="LICENSE">
    <img alt="License: GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## Why NextPass?

NextPass is a native KeePass client for iPhone, iPad, and Mac, built for people who want their vault to stay theirs. Open `.kdbx` databases from local files, Nextcloud, WebDAV, or FTP on every platform, and from iCloud Drive and other Files providers on iPhone and iPad; unlock with a master password, key file, or biometrics; then browse, search, edit, save, and AutoFill without handing your vault to a hosted password service.

NextPass is not on the App Store yet; builds go to testers through TestFlight.

> [!WARNING]
> **Test with a copy of your database, not your primary vault.** Test builds open your real `.kdbx` files.

## Highlights

| Area | What NextPass Does |
| --- | --- |
| **KeePass compatibility** | Reads and writes KDBX 4.x databases with AES-256, ChaCha20, or Twofish encryption and AES-KDF, Argon2d, or Argon2id. Also opens KDBX 3.1 databases in read-only mode. |
| **Local-first editing** | Create, edit, move, merge, and delete entries and groups; and save with conflict checks, timestamped backups, and preservation of entry history and unknown XML. |
| **New databases** | Create new KDBX 4.x databases locally or on a Nextcloud, WebDAV, or FTP server. |
| **Composite keys** | Unlock with password, key file, or both, including binary, hex, XML v1/v2 (`.key`/`.keyx`), and arbitrary key files. |
| **AutoFill** | Native password AutoFill in apps and browsers, with biometric unlock; iPhone and iPad additionally provide QuickType suggestions and password-entry creation from the extension. |
| **Passkeys** | Save and use FIDO2/WebAuthn passkeys in your KeePass database, in KeePassXC-compatible fields — added to an existing login entry or a new entry in the group you choose. |
| **Browser extension** | On the Mac, a Brave and Chrome extension lists the entries for the site you're on, searches your whole database, and fills the login. The database stays in NextPass, and each browser has to be approved with a matching code. |
| **TOTP** | Live one-time codes with countdowns and copy support, set up from QR codes or setup links, plus verification-code AutoFill on iOS 18+ and Mac. |
| **Apple Watch** | Entries tagged "Apple Watch" are copied to the Watch, whose verification codes keep working when the iPhone is out of range. |
| **Cloud sync** | Sign in to Nextcloud through the browser, or connect any WebDAV or FTP server, with read/write sync on every platform. |
| **Attachments** | View KeePass entry attachments, preview supported files with QuickLook, and share them from short-lived protected temporary files. Attachment editing is not yet supported. |
| **Native on every screen** | Focused iPhone navigation, a split-view iPad workspace, and a native Mac app with menus, commands, and Touch ID. |
| **Security** | AES-GCM in-memory secret encryption, failed-unlock backoff, decompression bomb limits, and constant-time HMAC comparison. |

## Privacy

NextPass has no analytics, no background telemetry, and no crash-reporting SDKs. Vault data stays on device and in the storage locations you choose. Network access is limited to the servers you connect, opt-in favicon fetching through DuckDuckGo, optional App Store purchases for the tip jar, and the in-app feedback form when you explicitly submit a message. The Mac app also listens on 127.0.0.1 for its browser extension, and only when you turn that on; nothing outside your Mac can reach it.

On iPhone and iPad, copied secrets are marked local-only so they do not travel through Universal Clipboard. macOS does not offer that exclusion, so copied secrets can follow your system's Universal Clipboard setting; NextPass marks them as concealed and clears its clipboard entry after a short while or when you lock the database. NextPass also protects app-switcher previews on iPhone and iPad. Screen-capture blocking on Mac is best-effort and may not stop every screenshot or recording.

## Data Safety

NextPass takes data safety very seriously: a password manager must never corrupt your vault or silently lose any part of it. Before any change ships, automated tests verify that:

- **Nothing gets lost when you save.** Every kind of edit is saved and read back piece by piece — passwords, notes, attachments, entry history, and even data from other KeePass apps that NextPass doesn't recognize must all come back exactly as they went in.
- **Your file is protected before it's touched.** NextPass refuses to overwrite changes made from elsewhere while you had the file open, writes a timestamped backup before every save, and rejects damaged databases outright instead of loading partial data.
- **An independent program agrees.** Every release must pass a gate where KeePassXC — a widely used KeePass app that shares no code with NextPass — opens databases NextPass wrote, decrypts the passwords, and confirms attachments match bit for bit. Databases created by other KeePass software must likewise open in NextPass and stay readable elsewhere after NextPass saves them.

For the technically curious, the test suite is mapped in [`KeeForgeTests/AGENTS.md`](KeeForgeTests/AGENTS.md) and the pre-release verification gate in [`ci_scripts/README.md`](ci_scripts/README.md).

## Origins

NextPass is a fork of [KeeForge](https://github.com/KeeForge/KeeForge), the open-source KeePass app by crazytan and contributors. The source folders, Xcode targets, and Swift types still carry that name.

## Project Map

```text
KeeForge/             # The app's shared source
├── App/              # App entry point, adaptive root shell, scene lifecycle
├── Extensions/       # Shared platform-compat helpers
├── Models/           # KDBX parser/writer, crypto, edit draft, TOTP, passkeys
├── Resources/        # String catalogs and asset catalogs
├── Services/         # Persistence, cloud sync, Keychain, bookmarks, attachments, AutoFill helpers, browser bridge
├── ViewModels/       # Database list, unlock, save, search, sort, TOTP state
├── Views/            # SwiftUI screens, editor, settings, tip jar, reusable controls
AutoFillExtension/    # AutoFill credential provider, passkey auth, credential creation
BrowserExtension/     # The Brave and Chrome extension
KeeForgeMac/          # Native macOS app configuration and entitlements
KeeForgeWatch/        # Apple Watch app
KeeForgeMacUITests/   # XCUITest coverage for the macOS app
KeeForgeTests/        # Unit tests
KeeForgeUITests/      # XCUITest coverage
TestFixtures/         # Sample .kdbx databases and key files
Vendor/               # Vendored Twofish Swift package
ci_scripts/           # Xcode Cloud bootstrap and release gate scripts
scripts/              # Local dev tooling
```

## Docs

- [`CHANGELOG.md`](CHANGELOG.md) - version history
- [`ROADMAP.md`](ROADMAP.md) - planned product work and open priorities
- [`AGENTS.md`](AGENTS.md) - context for coding agents
- [`KeeForge/README.md`](KeeForge/README.md) - app-target architecture map
- [`AutoFillExtension/AGENTS.md`](AutoFillExtension/AGENTS.md) - extension constraints and shared-source notes
- [`BrowserExtension/README.md`](BrowserExtension/README.md) - installing and using the browser extension
- [`SECURITY.md`](SECURITY.md) - vulnerability disclosure policy
- [`docs/macos-security-notes.md`](docs/macos-security-notes.md) - macOS security model, platform limits, and mitigations
- [`docs/`](docs/) - implementation specs, audits, and longer-form design docs

## Support

- Source and issues: [git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for build requirements, how to build from source, the pull request workflow, the Developer Certificate of Origin sign-off requirement, and licensing terms. Start with [`AGENTS.md`](AGENTS.md), then open the folder-local `README.md` closest to the code you are changing.

## License

NextPass is GPLv3 licensed, like KeeForge before it. See [`LICENSE`](LICENSE) for details.
