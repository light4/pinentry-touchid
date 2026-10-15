# pinentry-touchid（Swift）

[English](README.md) | 简体中文

macOS 原生 GnuPG pinentry，使用 Swift、AppKit、LocalAuthentication 和 Security.framework。
灵感来自 [jorgelbg/pinentry-touchid](https://github.com/jorgelbg/pinentry-touchid)，这是独立实现，不依赖 Go、Homebrew 或 `pinentry-mac`。

- 原生密码输入、重复输入校验、确认框和消息框。
- 用户主动勾选后保存密码到 Keychain，下次通过 Touch ID 验证后读取。
- 不记录密码或协议日志；取消或验证失败不会自动回退绕过验证。

## 快速开始

需要 macOS 13+、Swift 6+ / Xcode Command Line Tools，以及另行安装的 GnuPG。
Touch ID 需要兼容硬件及已登记的指纹；程序需要本机图形会话，不支持无头 SSH 终端回退。

```sh
swift build -c release
.build/release/pinentry-touchid --check
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

在 `~/.gnupg/gpg-agent.conf` 中添加或替换以下配置，改为自己的完整绝对路径：

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

```sh
gpg-connect-agent reloadagent /bye
```

构建不会自动安装或修改 GPG 配置。首次输入密码时勾选 **Save in Keychain for Touch ID**，才能在后续使用指纹解锁；这要求 GPG 允许外部缓存并提供 `SETKEYINFO`。gpg-agent 自身缓存有效期间不会触发指纹验证。

**安全提示：** Touch ID 验证在应用层执行，Keychain 条目没有生物识别 ACL；私钥仍由 GnuPG 管理，不在 Secure Enclave 中。本项目尚未完成安全审计。

## 文档

- [使用指南](docs/usage.zh-CN.md)：构建、GPG 配置、首次签名、指纹验证与缓存清理。
- [安全边界](docs/security.zh-CN.md)：Keychain 保护、内存限制与代码签名。
- [协议支持与限制](docs/protocol.zh-CN.md)：Assuan 命令、兼容性及验证状态。
- [开发指南](docs/development.zh-CN.md)：prek hooks 与黑盒 E2E 测试。
