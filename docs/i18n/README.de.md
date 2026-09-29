<p align="center">
  <img src="../../.github/assets/NextPass-icon-1024.png" alt="NextPass App-Icon" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  <a href="../../README.md">English</a> | Deutsch | <a href="README.fr.md">Français</a> | <a href="README.es.md">Español</a> | <a href="README.zh-Hans.md">简体中文</a> | <a href="README.zh-Hant.md">繁體中文</a> | <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  Ein kostenloser, quelloffener KeePass-Manager für iPhone, iPad, Mac und Apple Watch.
  <br />
  Natives SwiftUI, lokale Speicherung, AutoFill, Passkeys, TOTP, Nextcloud- und WebDAV-Sync und eine Browser-Erweiterung für Brave und Chrome.
</p>

<p align="center">
  <img alt="Erfordert iOS 18.0 oder neuer" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="Erfordert macOS 15.0 oder neuer" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="../../LICENSE">
    <img alt="Lizenz: GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## Warum NextPass?

NextPass ist ein nativer KeePass-Client für iPhone, iPad und Mac für alle, deren Tresor ihnen gehören soll. Öffne `.kdbx`-Datenbanken aus lokalen Dateien, Nextcloud, WebDAV oder FTP auf jeder Plattform und auf iPhone und iPad zusätzlich aus iCloud Drive und anderen Dateien-Anbietern; entsperre mit Master-Passwort, Schlüsseldatei oder Biometrie; dann durchsuchen, bearbeiten, speichern und per AutoFill ausfüllen, ohne deinen Tresor einem gehosteten Passwortdienst zu überlassen.

NextPass ist noch nicht im App Store; Builds gehen über TestFlight an Tester.

> [!WARNING]
> **Teste mit einer Kopie deiner Datenbank, nicht mit deinem Haupttresor.** Test-Builds öffnen deine echten `.kdbx`-Dateien.

## Highlights

| Bereich | Was NextPass kann |
| --- | --- |
| **KeePass-Kompatibilität** | Liest und schreibt KDBX-4.x-Datenbanken mit AES-256-, ChaCha20- oder Twofish-Verschlüsselung und AES-KDF, Argon2d oder Argon2id. Öffnet außerdem KDBX-3.1-Datenbanken schreibgeschützt. |
| **Lokales Bearbeiten** | Einträge und Gruppen anlegen, bearbeiten, verschieben, zusammenführen und löschen; speichern mit Konfliktprüfung, zeitgestempelten Backups und Erhalt von Eintragsverlauf und unbekanntem XML. |
| **Neue Datenbanken** | Neue KDBX-4.x-Datenbanken lokal oder auf einem Nextcloud-, WebDAV- oder FTP-Server anlegen. |
| **Zusammengesetzte Schlüssel** | Entsperren mit Passwort, Schlüsseldatei oder beidem, einschließlich Binär-, Hex-, XML-v1/v2- (`.key`/`.keyx`) und beliebiger Schlüsseldateien. |
| **AutoFill** | Natives Passwort-AutoFill in Apps und Browsern mit biometrischem Entsperren; iPhone und iPad bieten zusätzlich QuickType-Vorschläge und das Anlegen von Passworteinträgen aus der Erweiterung. |
| **Passkeys** | FIDO2/WebAuthn-Passkeys in deiner KeePass-Datenbank speichern und verwenden, in KeePassXC-kompatiblen Feldern – zu einem bestehenden Login-Eintrag hinzugefügt oder als neuer Eintrag in der Gruppe deiner Wahl. |
| **Browser-Erweiterung** | Auf dem Mac listet eine Erweiterung für Brave und Chrome die Einträge der aktuellen Website, durchsucht die ganze Datenbank und füllt das Login aus. Die Datenbank bleibt in NextPass, und jeder Browser muss mit einem übereinstimmenden Code freigegeben werden. |
| **TOTP** | Einmalcodes mit Countdown und Kopierfunktion, eingerichtet per QR-Code oder Setup-Link, dazu AutoFill für Bestätigungscodes ab iOS 18 und auf dem Mac. |
| **Apple Watch** | Mit „Apple Watch“ getaggte Einträge werden auf die Watch kopiert; deren Bestätigungscodes funktionieren auch, wenn das iPhone außer Reichweite ist. |
| **Cloud-Sync** | Bei Nextcloud über den Browser anmelden oder einen beliebigen WebDAV- oder FTP-Server verbinden, mit Lese-/Schreib-Sync auf jeder Plattform. |
| **Anhänge** | Anhänge von KeePass-Einträgen ansehen, unterstützte Dateien mit QuickLook voranzeigen und aus kurzlebigen, geschützten temporären Dateien teilen. Anhänge bearbeiten ist noch nicht möglich. |
| **Nativ auf jedem Bildschirm** | Fokussierte iPhone-Navigation, ein Split-View-Arbeitsbereich auf dem iPad und eine native Mac-App mit Menüs, Befehlen und Touch ID. |
| **Sicherheit** | AES-GCM-Verschlüsselung von Geheimnissen im Arbeitsspeicher, Wartezeit nach Fehlversuchen beim Entsperren, Schutz vor Dekompressionsbomben und HMAC-Vergleich in konstanter Zeit. |

## Datenschutz

NextPass hat keine Analyse, keine Hintergrund-Telemetrie und keine Crash-Reporting-SDKs. Tresordaten bleiben auf dem Gerät und in den Speicherorten, die du wählst. Netzwerkzugriffe beschränken sich auf die Server, die du verbindest, das optionale Laden von Website-Icons über DuckDuckGo, optionale App-Store-Käufe für das Trinkgeld und das Feedback-Formular in der App, wenn du ausdrücklich eine Nachricht sendest. Die Mac-App lauscht außerdem auf 127.0.0.1 auf ihre Browser-Erweiterung, und nur wenn du das einschaltest; von außerhalb deines Macs ist das nicht erreichbar.

Auf iPhone und iPad werden kopierte Geheimnisse als nur lokal markiert, damit sie nicht über die universelle Zwischenablage wandern. macOS bietet diese Ausnahme nicht, daher können kopierte Geheimnisse deiner Einstellung für die universelle Zwischenablage folgen; NextPass markiert sie als verborgen und leert seinen Eintrag in der Zwischenablage nach kurzer Zeit oder beim Sperren der Datenbank. NextPass schützt außerdem die Vorschauen im App-Umschalter auf iPhone und iPad. Das Blockieren von Bildschirmaufnahmen auf dem Mac erfolgt nach bestem Bemühen und verhindert nicht jeden Screenshot oder jede Aufnahme.

## Datensicherheit

NextPass nimmt Datensicherheit sehr ernst: Ein Passwortmanager darf deinen Tresor niemals beschädigen oder unbemerkt Teile davon verlieren. Bevor eine Änderung ausgeliefert wird, prüfen automatisierte Tests:

- **Beim Speichern geht nichts verloren.** Jede Art von Änderung wird gespeichert und Stück für Stück zurückgelesen – Passwörter, Notizen, Anhänge, Eintragsverlauf und sogar Daten anderer KeePass-Apps, die NextPass nicht kennt, müssen exakt so zurückkommen, wie sie hineingegangen sind.
- **Deine Datei ist geschützt, bevor sie angefasst wird.** NextPass überschreibt keine Änderungen, die anderswo vorgenommen wurden, während du die Datei geöffnet hattest, legt vor jedem Speichern ein zeitgestempeltes Backup an und weist beschädigte Datenbanken zurück, statt Teildaten zu laden.
- **Ein unabhängiges Programm bestätigt es.** Jedes Release muss ein Gate bestehen, in dem KeePassXC – eine verbreitete KeePass-App ohne gemeinsamen Code mit NextPass – von NextPass geschriebene Datenbanken öffnet, die Passwörter entschlüsselt und bestätigt, dass Anhänge Bit für Bit übereinstimmen. Datenbanken aus anderer KeePass-Software müssen ebenso in NextPass öffnen und nach dem Speichern durch NextPass anderswo lesbar bleiben.

Für technisch Interessierte: Die Test-Suite ist in [`KeeForgeTests/AGENTS.md`](../../KeeForgeTests/AGENTS.md) beschrieben, das Prüf-Gate vor jedem Release in [`ci_scripts/README.md`](../../ci_scripts/README.md) (beide auf Englisch).

## Herkunft

NextPass ist ein Fork von [KeeForge](https://github.com/KeeForge/KeeForge), der quelloffenen KeePass-App von crazytan und Mitwirkenden. Quellordner, Xcode-Targets und Swift-Typen tragen noch diesen Namen.

## Projektübersicht

```text
KeeForge/             # Gemeinsamer Quellcode der App
├── App/              # App-Einstiegspunkt, adaptive Root-Shell, Scene-Lifecycle
├── Extensions/       # Geteilte Plattform-Kompatibilitätshelfer
├── Models/           # KDBX-Parser/-Writer, Krypto, Bearbeitungsentwurf, TOTP, Passkeys
├── Resources/        # String-Kataloge und Asset-Kataloge
├── Services/         # Persistenz, Cloud-Sync, Keychain, Bookmarks, Anhänge, AutoFill-Helfer, Browser-Anbindung
├── ViewModels/       # Datenbankliste, Entsperren, Speichern, Suche, Sortierung, TOTP-State
├── Views/            # SwiftUI-Screens, Editor, Einstellungen, Trinkgeld, wiederverwendbare Controls
AutoFillExtension/    # AutoFill-Credential-Provider, Passkey-Auth, Anlegen von Zugangsdaten
BrowserExtension/     # Die Erweiterung für Brave und Chrome
KeeForgeMac/          # Konfiguration und Entitlements der nativen macOS-App
KeeForgeWatch/        # Apple-Watch-App
KeeForgeMacUITests/   # XCUITest-Abdeckung für die macOS-App
KeeForgeTests/        # Unit-Tests
KeeForgeUITests/      # XCUITest-Abdeckung
TestFixtures/         # Beispiel-.kdbx-Datenbanken und Schlüsseldateien
Vendor/               # Lokal mitgeliefertes Twofish-Swift-Package
ci_scripts/           # Xcode-Cloud-Bootstrap- und Release-Gate-Skripte
scripts/              # Lokale Entwickler-Tools
```

## Dokumentation

- [`CHANGELOG.md`](../../CHANGELOG.md) – Versionshistorie
- [`ROADMAP.md`](../../ROADMAP.md) – geplante Produktarbeit und offene Prioritäten
- [`AGENTS.md`](../../AGENTS.md) – Kontext für Coding-Agents
- [`KeeForge/README.md`](../../KeeForge/README.md) – Architekturübersicht des App-Targets
- [`AutoFillExtension/AGENTS.md`](../../AutoFillExtension/AGENTS.md) – Extension-Einschränkungen und Hinweise zu geteiltem Code
- [`BrowserExtension/README.md`](../../BrowserExtension/README.md) – Browser-Erweiterung installieren und verwenden
- [`SECURITY.md`](../../SECURITY.md) – Richtlinie zur Meldung von Sicherheitslücken
- [`docs/macos-security-notes.md`](../../docs/macos-security-notes.md) – macOS-Sicherheitsmodell, Plattformgrenzen und Gegenmaßnahmen
- [`docs/`](../../docs/) – Implementierungs-Specs, Audits und längere Design-Dokumente

Außer dieser README und [`CONTRIBUTING.de.md`](CONTRIBUTING.de.md) wird die Entwicklerdokumentation nur auf Englisch gepflegt.

## Support

- Quellcode und Issues: [git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## Mitwirken

Siehe [`CONTRIBUTING.de.md`](CONTRIBUTING.de.md) für die Build-Voraussetzungen, das Bauen aus dem Quellcode, den Pull-Request-Workflow, die Sign-off-Pflicht nach dem Developer Certificate of Origin und die Lizenzbedingungen. Beginne mit [`AGENTS.md`](../../AGENTS.md) und öffne dann die ordnerlokale `README.md`, die dem Code am nächsten liegt, den du änderst.

## Lizenz

NextPass ist wie zuvor KeeForge unter der GPLv3 lizenziert. Details in [`LICENSE`](../../LICENSE).
