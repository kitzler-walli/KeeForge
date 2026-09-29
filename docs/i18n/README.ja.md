<p align="center">
  <img src="../../.github/assets/NextPass-icon-1024.png" alt="NextPass アプリアイコン" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.de.md">Deutsch</a> | <a href="README.fr.md">Français</a> | <a href="README.es.md">Español</a> | <a href="README.zh-Hans.md">简体中文</a> | <a href="README.zh-Hant.md">繁體中文</a> | 日本語
</p>

<p align="center">
  iPhone、iPad、Mac、Apple Watch 向けの無料でオープンソースの KeePass マネージャー。
  <br />
  ネイティブ SwiftUI、ローカル優先のストレージ、自動入力、パスキー、TOTP、Nextcloud・WebDAV 同期、Brave と Chrome 向けブラウザ拡張機能。
</p>

<p align="center">
  <img alt="iOS 18.0 以降が必要" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="macOS 15.0 以降が必要" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="../../LICENSE">
    <img alt="ライセンス: GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## NextPass を選ぶ理由

NextPass は、保管庫を自分の手元に置いておきたい人のための、iPhone、iPad、Mac 向けネイティブ KeePass クライアントです。すべてのプラットフォームでローカルファイル、Nextcloud、WebDAV、FTP から `.kdbx` データベースを開け、iPhone と iPad では iCloud Drive などの「ファイル」プロバイダからも開けます。マスターパスワード、キーファイル、生体認証でロックを解除し、閲覧、検索、編集、保存、自動入力まで、ホスト型のパスワードサービスに保管庫を預けることなく行えます。

NextPass はまだ App Store にはありません。ビルドは TestFlight でテスターに配布されます。

> [!WARNING]
> **メインの保管庫ではなく、データベースのコピーでテストしてください。** テストビルドは実際の `.kdbx` ファイルを開きます。

## 主な特長

| 分野 | NextPass でできること |
| --- | --- |
| **KeePass 互換性** | AES-256、ChaCha20、Twofish 暗号化と AES-KDF、Argon2d、Argon2id を使った KDBX 4.x データベースの読み書きに対応。KDBX 3.1 データベースも読み取り専用で開けます。 |
| **ローカル優先の編集** | エントリとグループの作成、編集、移動、統合、削除。競合チェック、タイムスタンプ付きバックアップ、エントリ履歴と未知の XML の保持を伴って保存します。 |
| **新規データベース** | 新しい KDBX 4.x データベースをローカル、または Nextcloud、WebDAV、FTP サーバ上に作成できます。 |
| **複合キー** | パスワード、キーファイル、またはその両方でロック解除。バイナリ、16 進、XML v1/v2（`.key`/`.keyx`）、任意のキーファイルに対応します。 |
| **自動入力** | アプリとブラウザでのネイティブなパスワード自動入力と生体認証によるロック解除。iPhone と iPad では QuickType の候補表示と、拡張機能からのパスワードエントリ作成にも対応します。 |
| **パスキー** | FIDO2/WebAuthn パスキーを KeePassXC 互換のフィールドとして KeePass データベースに保存して使用。既存のログインエントリに追加するか、選んだグループに新しいエントリとして作成できます。 |
| **ブラウザ拡張機能** | Mac では、Brave と Chrome 向けの拡張機能が表示中のサイトのエントリを一覧表示し、データベース全体を検索してログインを入力します。データベースは NextPass に残り、各ブラウザは一致するコードで承認する必要があります。 |
| **TOTP** | カウントダウンとコピーに対応したワンタイムコード。QR コードやセットアップリンクから設定でき、iOS 18 以降と Mac では確認コードの自動入力にも対応します。 |
| **Apple Watch** | 「Apple Watch」タグを付けたエントリを Watch にコピー。iPhone が圏外でも Watch の確認コードは使い続けられます。 |
| **クラウド同期** | ブラウザ経由で Nextcloud にサインインするか、任意の WebDAV・FTP サーバに接続し、すべてのプラットフォームで読み書き同期できます。 |
| **添付ファイル** | KeePass エントリの添付ファイルを表示し、対応ファイルをクイックルックでプレビュー、短時間だけ存在する保護された一時ファイルから共有できます。添付ファイルの編集にはまだ対応していません。 |
| **どの画面でもネイティブ** | iPhone ではシンプルなナビゲーション、iPad では分割ビューのワークスペース、Mac ではメニュー、コマンド、Touch ID を備えたネイティブアプリ。 |
| **セキュリティ** | メモリ内シークレットの AES-GCM 暗号化、ロック解除失敗時の待機時間、展開爆弾への制限、定数時間の HMAC 比較。 |

## プライバシー

NextPass には分析、バックグラウンドのテレメトリ、クラッシュレポート SDK は一切ありません。保管庫のデータはデバイス上と、あなたが選んだ保存場所にとどまります。ネットワークアクセスは、接続したサーバ、DuckDuckGo 経由のサイトアイコン取得（任意）、チップジャーの App Store 購入（任意）、明示的にメッセージを送信したときのアプリ内フィードバックフォームに限られます。Mac アプリは、有効にした場合に限り、ブラウザ拡張機能のために 127.0.0.1 で待ち受けます。Mac の外部からは到達できません。

iPhone と iPad では、コピーしたシークレットはローカル専用としてマークされ、ユニバーサルクリップボードを経由しません。macOS にはこの除外機能がないため、コピーしたシークレットはシステムのユニバーサルクリップボード設定に従う場合があります。NextPass はそれらを非表示としてマークし、少し時間が経つかデータベースをロックすると、自分のクリップボード項目を消去します。iPhone と iPad ではアプリスイッチャーのプレビューも保護します。Mac の画面収録ブロックはベストエフォートであり、すべてのスクリーンショットや録画を防げるとは限りません。

## データの安全性

NextPass はデータの安全性を非常に重視しています。パスワードマネージャーは保管庫を壊したり、その一部を気づかないうちに失ったりしてはなりません。変更を出荷する前に、自動テストで次のことを確認しています。

- **保存しても何も失われない。** あらゆる種類の編集を保存し、一つずつ読み戻します。パスワード、メモ、添付ファイル、エントリ履歴、さらに NextPass が認識しない他の KeePass アプリのデータまで、入れたとおりに戻ってこなければなりません。
- **触れる前にファイルを守る。** ファイルを開いている間にほかで行われた変更を NextPass は上書きせず、保存のたびにタイムスタンプ付きのバックアップを作成し、破損したデータベースは部分的に読み込まずに拒否します。
- **独立したプログラムが確認する。** すべてのリリースは、NextPass とコードを一切共有しない広く使われている KeePass アプリ KeePassXC が、NextPass の書き込んだデータベースを開き、パスワードを復号し、添付ファイルがビット単位で一致することを確認する検証を通過しなければなりません。ほかの KeePass ソフトウェアで作成したデータベースも NextPass で開け、NextPass が保存した後もほかのアプリで読めなければなりません。

技術的な詳細に興味がある方へ：テストスイートは [`KeeForgeTests/AGENTS.md`](../../KeeForgeTests/AGENTS.md)、リリース前の検証は [`ci_scripts/README.md`](../../ci_scripts/README.md) にまとめています（いずれも英語）。

## 由来

NextPass は、crazytan と貢献者によるオープンソースの KeePass アプリ [KeeForge](https://github.com/KeeForge/KeeForge) のフォークです。ソースフォルダ、Xcode ターゲット、Swift の型には今もその名前が残っています。

## プロジェクトの構成

```text
KeeForge/             # アプリの共有ソース
├── App/              # アプリのエントリポイント、アダプティブなルートシェル、シーンのライフサイクル
├── Extensions/       # プラットフォーム互換の共有ヘルパー
├── Models/           # KDBX パーサ/ライタ、暗号、編集ドラフト、TOTP、パスキー
├── Resources/        # 文字列カタログとアセットカタログ
├── Services/         # 永続化、クラウド同期、キーチェーン、ブックマーク、添付ファイル、自動入力、ブラウザ連携
├── ViewModels/       # データベース一覧、ロック解除、保存、検索、並べ替え、TOTP の状態
├── Views/            # SwiftUI 画面、エディタ、設定、チップジャー、再利用可能なコントロール
AutoFillExtension/    # 自動入力の資格情報プロバイダ、パスキー認証、資格情報の作成
BrowserExtension/     # Brave と Chrome 向けの拡張機能
KeeForgeMac/          # ネイティブ macOS アプリの設定とエンタイトルメント
KeeForgeWatch/        # Apple Watch アプリ
KeeForgeMacUITests/   # macOS アプリの XCUITest
KeeForgeTests/        # ユニットテスト
KeeForgeUITests/      # XCUITest
TestFixtures/         # サンプルの .kdbx データベースとキーファイル
Vendor/               # 同梱の Twofish Swift パッケージ
ci_scripts/           # Xcode Cloud の初期化とリリース検証のスクリプト
scripts/              # ローカル開発ツール
```

## ドキュメント

- [`CHANGELOG.md`](../../CHANGELOG.md) – バージョン履歴
- [`ROADMAP.md`](../../ROADMAP.md) – 予定している作業と優先事項
- [`AGENTS.md`](../../AGENTS.md) – コーディングエージェント向けのコンテキスト
- [`KeeForge/README.md`](../../KeeForge/README.md) – アプリターゲットのアーキテクチャ
- [`AutoFillExtension/AGENTS.md`](../../AutoFillExtension/AGENTS.md) – 拡張機能の制約と共有コードの注意点
- [`BrowserExtension/README.md`](../../BrowserExtension/README.md) – ブラウザ拡張機能のインストールと使い方
- [`SECURITY.md`](../../SECURITY.md) – 脆弱性の報告ポリシー
- [`docs/macos-security-notes.md`](../../docs/macos-security-notes.md) – macOS のセキュリティモデル、プラットフォームの制限と対策
- [`docs/`](../../docs/) – 実装仕様、監査、詳細な設計ドキュメント

この README と [`CONTRIBUTING.ja.md`](CONTRIBUTING.ja.md) を除き、開発者向けドキュメントは英語のみで管理されています。

## サポート

- ソースコードと課題： [git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## 貢献する

ビルドの要件、ソースからのビルド方法、プルリクエストの進め方、Developer Certificate of Origin の署名要件、ライセンス条項については [`CONTRIBUTING.ja.md`](CONTRIBUTING.ja.md) をご覧ください。まず [`AGENTS.md`](../../AGENTS.md) を読み、次に変更するコードに最も近いフォルダ内の `README.md` を開いてください。

## ライセンス

NextPass は KeeForge と同じく GPLv3 でライセンスされています。詳しくは [`LICENSE`](../../LICENSE) をご覧ください。
