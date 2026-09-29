<p align="center">
  <img src="../../.github/assets/NextPass-icon-1024.png" alt="NextPass App 圖像" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.de.md">Deutsch</a> | <a href="README.fr.md">Français</a> | <a href="README.es.md">Español</a> | <a href="README.zh-Hans.md">简体中文</a> | 繁體中文 | <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  適用於 iPhone、iPad、Mac 與 Apple Watch 的免費開源 KeePass 管理工具。
  <br />
  原生 SwiftUI、本機優先儲存、自動填寫、通行密鑰、TOTP、Nextcloud 與 WebDAV 同步，以及適用於 Brave 與 Chrome 的瀏覽器延伸功能。
</p>

<p align="center">
  <img alt="需要 iOS 18.0 或以上版本" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="需要 macOS 15.0 或以上版本" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="../../LICENSE">
    <img alt="授權條款：GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## 為什麼選擇 NextPass？

NextPass 是適用於 iPhone、iPad 與 Mac 的原生 KeePass 用戶端，為想要完全掌握自己密碼庫的人打造。在所有平台上都能從本機檔案、Nextcloud、WebDAV 或 FTP 開啟 `.kdbx` 資料庫，在 iPhone 與 iPad 上也能從 iCloud 雲碟及其他「檔案」提供者開啟；以主密碼、密鑰檔案或生物辨識解鎖；接著瀏覽、搜尋、編輯、儲存與自動填寫，不必把密碼庫交給託管的密碼服務。

NextPass 尚未上架 App Store；建置版本透過 TestFlight 發送給測試人員。

> [!WARNING]
> **請用資料庫的副本測試，不要用你的主要密碼庫。** 測試版本會開啟你真實的 `.kdbx` 檔案。

## 功能亮點

| 領域 | NextPass 的功能 |
| --- | --- |
| **KeePass 相容性** | 讀寫使用 AES-256、ChaCha20 或 Twofish 加密，以及 AES-KDF、Argon2d 或 Argon2id 的 KDBX 4.x 資料庫。也能以唯讀模式開啟 KDBX 3.1 資料庫。 |
| **本機優先編輯** | 建立、編輯、搬移、合併與刪除項目及群組；儲存時進行衝突檢查、建立帶時間戳記的備份，並保留項目歷史與未知 XML。 |
| **新增資料庫** | 在本機或 Nextcloud、WebDAV、FTP 伺服器上建立新的 KDBX 4.x 資料庫。 |
| **複合密鑰** | 以密碼、密鑰檔案或兩者一起解鎖，支援二進位、十六進位、XML v1/v2（`.key`/`.keyx`）及任意密鑰檔案。 |
| **自動填寫** | 在 App 與瀏覽器中原生自動填寫密碼，並支援生物辨識解鎖；iPhone 與 iPad 另提供 QuickType 建議，並可從延伸功能建立密碼項目。 |
| **通行密鑰** | 將 FIDO2/WebAuthn 通行密鑰以 KeePassXC 相容的欄位儲存在 KeePass 資料庫中並使用——可加入現有的登入項目，或在你選擇的群組中建立新項目。 |
| **瀏覽器延伸功能** | 在 Mac 上，Brave 與 Chrome 延伸功能會列出目前網站的項目、搜尋整個資料庫並填寫登入資訊。資料庫一直留在 NextPass 中，每個瀏覽器都必須以相符的代碼取得核准。 |
| **TOTP** | 附倒數計時與拷貝功能的一次性代碼，可透過 QR 碼或設定連結加入；在 iOS 18 以上與 Mac 上也支援驗證碼自動填寫。 |
| **Apple Watch** | 加上「Apple Watch」標籤的項目會拷貝到手錶上，即使 iPhone 不在範圍內，手錶上的驗證碼仍可繼續使用。 |
| **雲端同步** | 透過瀏覽器登入 Nextcloud，或連接任何 WebDAV、FTP 伺服器，在所有平台上讀寫同步。 |
| **附件** | 檢視 KeePass 項目附件，以快速查看預覽支援的檔案，並透過短暫存在的受保護暫存檔案分享。尚不支援編輯附件。 |
| **每個螢幕都原生** | iPhone 上專注的導覽、iPad 上的分割畫面工作區，以及具備選單、指令與 Touch ID 的原生 Mac App。 |
| **安全性** | 記憶體中機密的 AES-GCM 加密、解鎖失敗後的延遲等待、解壓縮炸彈限制，以及固定時間的 HMAC 比對。 |

## 隱私權

NextPass 沒有分析、沒有背景遙測，也沒有當機回報 SDK。密碼庫資料留在裝置上及你選擇的儲存位置。網路存取僅限於你連接的伺服器、透過 DuckDuckGo 取得網站圖像（選用）、用於小費的 App Store 購買（選用），以及你明確送出訊息時的 App 內意見回饋表單。Mac App 只有在你開啟後，才會在 127.0.0.1 上監聽其瀏覽器延伸功能；Mac 以外的任何裝置都無法連線。

在 iPhone 與 iPad 上，拷貝的機密會標記為僅限本機，因此不會經過通用剪貼板。macOS 不提供這種排除方式，因此拷貝的機密可能會依循系統的通用剪貼板設定；NextPass 會將其標記為隱藏，並在短時間後或鎖定資料庫時清除其剪貼板內容。NextPass 也會在 iPhone 與 iPad 上保護 App 切換器中的預覽。Mac 上的螢幕錄製阻擋功能僅為盡力而為，可能無法阻止所有螢幕截圖或錄製。

## 資料安全

NextPass 非常重視資料安全：密碼管理工具絕不能損壞你的密碼庫，也不能在不知不覺中遺失其中任何部分。每項變更發佈前，自動化測試都會驗證：

- **儲存時不會遺失任何內容。** 每種編輯都會儲存並逐項讀回——密碼、備註、附件、項目歷史，甚至 NextPass 無法辨識的其他 KeePass App 資料，都必須原封不動地回來。
- **在變更檔案前先保護它。** 若檔案在你開啟期間於其他地方被修改，NextPass 會拒絕覆寫；每次儲存前都會建立帶時間戳記的備份，並直接拒絕損壞的資料庫，而不是載入部分資料。
- **由獨立程式加以確認。** 每個版本都必須通過一道檢驗：由與 NextPass 不共用任何程式碼的常用 KeePass App——KeePassXC——開啟 NextPass 寫入的資料庫、解密密碼，並確認附件逐位元相符。其他 KeePass 軟體建立的資料庫也必須能在 NextPass 中開啟，並在 NextPass 儲存後仍可於其他地方讀取。

想了解技術細節，可參閱 [`KeeForgeTests/AGENTS.md`](../../KeeForgeTests/AGENTS.md) 中的測試套件說明，以及 [`ci_scripts/README.md`](../../ci_scripts/README.md) 中的發佈前驗證（皆為英文）。

## 由來

NextPass 是 [KeeForge](https://github.com/KeeForge/KeeForge) 的分支，KeeForge 是由 crazytan 與貢獻者開發的開源 KeePass App。原始碼資料夾、Xcode target 與 Swift 型別仍沿用這個名稱。

## 專案地圖

```text
KeeForge/             # App 的共用原始碼
├── App/              # App 進入點、自適應根殼層、場景生命週期
├── Extensions/       # 共用的平台相容輔助工具
├── Models/           # KDBX 解析/寫入、加密、編輯草稿、TOTP、通行密鑰
├── Resources/        # 字串目錄與資源目錄
├── Services/         # 資料保存、雲端同步、鑰匙圈、書籤、附件、自動填寫輔助、瀏覽器橋接
├── ViewModels/       # 資料庫列表、解鎖、儲存、搜尋、排序、TOTP 狀態
├── Views/            # SwiftUI 畫面、編輯器、設定、小費、可重複使用的控制項
AutoFillExtension/    # 自動填寫憑證提供者、通行密鑰驗證、憑證建立
BrowserExtension/     # Brave 與 Chrome 延伸功能
KeeForgeMac/          # 原生 macOS App 的設定與權限
KeeForgeWatch/        # Apple Watch App
KeeForgeMacUITests/   # macOS App 的 XCUITest
KeeForgeTests/        # 單元測試
KeeForgeUITests/      # XCUITest
TestFixtures/         # 範例 .kdbx 資料庫與密鑰檔案
Vendor/               # 內建的 Twofish Swift 套件
ci_scripts/           # Xcode Cloud 啟動與發佈檢驗腳本
scripts/              # 本機開發工具
```

## 文件

- [`CHANGELOG.md`](../../CHANGELOG.md) – 版本歷史
- [`ROADMAP.md`](../../ROADMAP.md) – 規劃中的工作與待定優先事項
- [`AGENTS.md`](../../AGENTS.md) – 給程式碼代理的背景資訊
- [`KeeForge/README.md`](../../KeeForge/README.md) – App target 架構概覽
- [`AutoFillExtension/AGENTS.md`](../../AutoFillExtension/AGENTS.md) – 延伸功能的限制與共用程式碼說明
- [`BrowserExtension/README.md`](../../BrowserExtension/README.md) – 安裝與使用瀏覽器延伸功能
- [`SECURITY.md`](../../SECURITY.md) – 漏洞揭露政策
- [`docs/macos-security-notes.md`](../../docs/macos-security-notes.md) – macOS 安全模型、平台限制與緩解措施
- [`docs/`](../../docs/) – 實作規格、稽核與詳細設計文件

除了本 README 與 [`CONTRIBUTING.zh-Hant.md`](CONTRIBUTING.zh-Hant.md) 之外，開發者文件僅以英文維護。

## 支援

- 原始碼與問題回報：[git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## 參與貢獻

請參閱 [`CONTRIBUTING.zh-Hant.md`](CONTRIBUTING.zh-Hant.md)，了解建置需求、如何從原始碼建置、Pull Request 工作流程、Developer Certificate of Origin 簽署要求與授權條款。先從 [`AGENTS.md`](../../AGENTS.md) 開始，再開啟離你要修改的程式碼最近的資料夾內 `README.md`。

## 授權條款

NextPass 與先前的 KeeForge 一樣，採用 GPLv3 授權條款。詳情請參閱 [`LICENSE`](../../LICENSE)。
