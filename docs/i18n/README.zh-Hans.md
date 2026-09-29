<p align="center">
  <img src="../../.github/assets/NextPass-icon-1024.png" alt="NextPass 应用图标" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.de.md">Deutsch</a> | <a href="README.fr.md">Français</a> | <a href="README.es.md">Español</a> | 简体中文 | <a href="README.zh-Hant.md">繁體中文</a> | <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  适用于 iPhone、iPad、Mac 和 Apple Watch 的免费开源 KeePass 管理器。
  <br />
  原生 SwiftUI、本地优先存储、自动填充、通行密钥、TOTP、Nextcloud 与 WebDAV 同步，以及适用于 Brave 和 Chrome 的浏览器扩展。
</p>

<p align="center">
  <img alt="需要 iOS 18.0 或更高版本" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="需要 macOS 15.0 或更高版本" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="../../LICENSE">
    <img alt="许可证：GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## 为什么选择 NextPass？

NextPass 是一款适用于 iPhone、iPad 和 Mac 的原生 KeePass 客户端，为希望完全掌控自己密码库的人而打造。在所有平台上都可以从本地文件、Nextcloud、WebDAV 或 FTP 打开 `.kdbx` 数据库，在 iPhone 和 iPad 上还可以从 iCloud 云盘及其他“文件”提供方打开；使用主密码、密钥文件或生物识别解锁；然后浏览、搜索、编辑、保存和自动填充，无需把密码库交给托管的密码服务。

NextPass 尚未上架 App Store；构建版本通过 TestFlight 分发给测试人员。

> [!WARNING]
> **请用数据库的副本测试，不要用你的主密码库。** 测试版本会打开你真实的 `.kdbx` 文件。

## 亮点

| 方面 | NextPass 的功能 |
| --- | --- |
| **KeePass 兼容性** | 读写使用 AES-256、ChaCha20 或 Twofish 加密以及 AES-KDF、Argon2d 或 Argon2id 的 KDBX 4.x 数据库。也能以只读方式打开 KDBX 3.1 数据库。 |
| **本地优先编辑** | 创建、编辑、移动、合并和删除条目与群组；保存时进行冲突检查、创建带时间戳的备份，并保留条目历史和未知 XML。 |
| **新建数据库** | 在本地或 Nextcloud、WebDAV、FTP 服务器上创建新的 KDBX 4.x 数据库。 |
| **组合密钥** | 使用密码、密钥文件或两者一起解锁，支持二进制、十六进制、XML v1/v2（`.key`/`.keyx`）及任意密钥文件。 |
| **自动填充** | 在 App 和浏览器中原生自动填充密码，并支持生物识别解锁；iPhone 和 iPad 还提供 QuickType 建议，并可从扩展中创建密码条目。 |
| **通行密钥** | 将 FIDO2/WebAuthn 通行密钥以 KeePassXC 兼容的字段保存在 KeePass 数据库中并使用——可添加到现有登录条目，或在你选择的群组中新建条目。 |
| **浏览器扩展** | 在 Mac 上，Brave 和 Chrome 扩展会列出当前网站的条目、搜索整个数据库并填写登录信息。数据库始终留在 NextPass 中，每个浏览器都必须通过一致的验证码获得批准。 |
| **TOTP** | 带倒计时和复制功能的一次性验证码，可通过二维码或设置链接添加；在 iOS 18 及以上版本和 Mac 上还支持验证码自动填充。 |
| **Apple Watch** | 带“Apple Watch”标签的条目会复制到手表上，即使 iPhone 不在附近，手表上的验证码也能继续使用。 |
| **云同步** | 通过浏览器登录 Nextcloud，或连接任意 WebDAV、FTP 服务器，在所有平台上读写同步。 |
| **附件** | 查看 KeePass 条目附件，使用快速查看预览支持的文件，并通过短暂存在的受保护临时文件分享。暂不支持编辑附件。 |
| **每块屏幕都原生** | iPhone 上专注的导航、iPad 上的分栏工作区，以及带菜单、命令和触控 ID 的原生 Mac App。 |
| **安全** | 内存中秘密的 AES-GCM 加密、解锁失败后的退避等待、解压炸弹限制，以及恒定时间的 HMAC 比较。 |

## 隐私

NextPass 没有分析、没有后台遥测，也没有崩溃报告 SDK。密码库数据留在设备上以及你选择的存储位置。网络访问仅限于你连接的服务器、通过 DuckDuckGo 获取网站图标（可选）、用于小费的 App Store 购买（可选），以及你明确发送消息时的 App 内反馈表单。Mac App 只有在你开启后，才会在 127.0.0.1 上监听其浏览器扩展；Mac 之外的任何设备都无法访问。

在 iPhone 和 iPad 上，复制的秘密会被标记为仅限本地，因此不会经过通用剪贴板。macOS 不提供这种排除方式，因此复制的秘密可能会遵循系统的通用剪贴板设置；NextPass 会将其标记为隐藏，并在短时间后或锁定数据库时清除其剪贴板内容。NextPass 还会在 iPhone 和 iPad 上保护 App 切换器中的预览。Mac 上的屏幕录制阻止功能是尽力而为的，可能无法阻止所有截图或录制。

## 数据安全

NextPass 非常重视数据安全：密码管理器绝不能损坏你的密码库，也不能悄无声息地丢失其中任何部分。每项更改发布前，自动化测试都会验证：

- **保存时不会丢失任何内容。** 每种编辑都会被保存并逐项读回——密码、备注、附件、条目历史，甚至 NextPass 无法识别的其他 KeePass App 的数据，都必须原样返回。
- **在改动文件之前先保护它。** 如果文件在你打开期间被其他地方修改，NextPass 会拒绝覆盖；每次保存前都会创建带时间戳的备份，并直接拒绝损坏的数据库，而不是加载部分数据。
- **独立程序加以确认。** 每个版本都必须通过一道检验：由与 NextPass 不共享任何代码的常用 KeePass App——KeePassXC——打开 NextPass 写入的数据库、解密密码，并确认附件逐位一致。其他 KeePass 软件创建的数据库也必须能在 NextPass 中打开，并在 NextPass 保存后仍可在其他地方读取。

想了解技术细节，可参阅 [`KeeForgeTests/AGENTS.md`](../../KeeForgeTests/AGENTS.md) 中的测试套件说明，以及 [`ci_scripts/README.md`](../../ci_scripts/README.md) 中的发布前验证（均为英文）。

## 由来

NextPass 是 [KeeForge](https://github.com/KeeForge/KeeForge) 的分支，KeeForge 是由 crazytan 及贡献者开发的开源 KeePass App。源代码文件夹、Xcode target 和 Swift 类型仍沿用这个名称。

## 项目结构

```text
KeeForge/             # App 的共享源代码
├── App/              # App 入口、自适应根壳层、场景生命周期
├── Extensions/       # 共享的平台兼容辅助工具
├── Models/           # KDBX 解析/写入、加密、编辑草稿、TOTP、通行密钥
├── Resources/        # 字符串目录和资源目录
├── Services/         # 持久化、云同步、钥匙串、书签、附件、自动填充辅助、浏览器桥接
├── ViewModels/       # 数据库列表、解锁、保存、搜索、排序、TOTP 状态
├── Views/            # SwiftUI 界面、编辑器、设置、小费、可复用控件
AutoFillExtension/    # 自动填充凭证提供方、通行密钥认证、凭证创建
BrowserExtension/     # Brave 和 Chrome 扩展
KeeForgeMac/          # 原生 macOS App 的配置和权限
KeeForgeWatch/        # Apple Watch App
KeeForgeMacUITests/   # macOS App 的 XCUITest
KeeForgeTests/        # 单元测试
KeeForgeUITests/      # XCUITest
TestFixtures/         # 示例 .kdbx 数据库和密钥文件
Vendor/               # 内置的 Twofish Swift 包
ci_scripts/           # Xcode Cloud 引导和发布检验脚本
scripts/              # 本地开发工具
```

## 文档

- [`CHANGELOG.md`](../../CHANGELOG.md) – 版本历史
- [`ROADMAP.md`](../../ROADMAP.md) – 计划中的工作和待定优先事项
- [`AGENTS.md`](../../AGENTS.md) – 给编码代理的背景信息
- [`KeeForge/README.md`](../../KeeForge/README.md) – App target 架构概览
- [`AutoFillExtension/AGENTS.md`](../../AutoFillExtension/AGENTS.md) – 扩展的限制和共享代码说明
- [`BrowserExtension/README.md`](../../BrowserExtension/README.md) – 安装和使用浏览器扩展
- [`SECURITY.md`](../../SECURITY.md) – 漏洞披露政策
- [`docs/macos-security-notes.md`](../../docs/macos-security-notes.md) – macOS 安全模型、平台限制和缓解措施
- [`docs/`](../../docs/) – 实现规范、审计和详细设计文档

除本 README 和 [`CONTRIBUTING.zh-Hans.md`](CONTRIBUTING.zh-Hans.md) 外，开发者文档仅以英文维护。

## 支持

- 源代码和问题反馈：[git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## 参与贡献

构建要求、如何从源码构建、pull request 工作流程、Developer Certificate of Origin 签署要求以及许可条款，请参阅 [`CONTRIBUTING.zh-Hans.md`](CONTRIBUTING.zh-Hans.md)。先从 [`AGENTS.md`](../../AGENTS.md) 开始，再打开距离你要修改的代码最近的文件夹内 `README.md`。

## 许可证

NextPass 与之前的 KeeForge 一样，采用 GPLv3 许可证。详情请参阅 [`LICENSE`](../../LICENSE)。
