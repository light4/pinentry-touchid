# pinentry-touchid（Swift）

macOS 原生 GnuPG pinentry，使用 Swift、AppKit、LocalAuthentication 和 Security.framework。
灵感来自 [jorgelbg/pinentry-touchid](https://github.com/jorgelbg/pinentry-touchid)，这是独立实现，不依赖 Go、Homebrew 或 `pinentry-mac`。

## 功能

- 通过 stdin/stdout 提供 pinentry Assuan 协议。
- 自带原生密码弹窗、重复输入校验、确认框和消息框。
- 当 GPG 允许外部缓存且提供 `SETKEYINFO` 时，用户可以**主动勾选**保存密码到 Keychain；默认不勾选。
- 下次需要密码时，先验证 Touch ID，再读取 Keychain。
- Touch ID 不可用或用户选择“Enter GPG Passphrase”时，使用原生密码输入。
- 取消或验证失败会返回错误，不自动读取密码，也不会自动改用密码输入绕过取消。
- GPG 报告密码错误时，删除对应旧缓存并重新询问；新建密码的重复输入流程不使用外部缓存。
- 支持 `SETTIMEOUT` / `--timeout`、UTF-8、percent escaping 和长密码的分段数据响应。
- 不记录密码或协议日志。

## 要求与构建

- macOS 13+；指纹功能需要可用的 Touch ID 硬件及已登记的指纹。
- Swift 6+ / Xcode Command Line Tools。
- GnuPG 由用户另行安装。
- 需要本机图形会话；没有实现无头 SSH 的终端回退。

```sh
cd ~/sources/pinentry-touchid
swift build -c release
.build/release/pinentry-touchid --help
.build/release/pinentry-touchid --check
```

构建后的可执行文件：`.build/release/pinentry-touchid`。
`--check` 仅检查 Touch ID 是否可用，不显示认证弹窗、不读取密码。

## 配置 GPG

**构建不会自动安装，也不会改动 GPG 配置。** 可手动复制到固定位置：

```sh
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

在 `~/.gnupg/gpg-agent.conf` 中设置 `pinentry-program`，替换已有的同名配置，使用完整绝对路径而不是 `~`：

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

然后重新加载 agent：

```sh
gpg-connect-agent reloadagent /bye
```

如果已有 `no-allow-external-cache`，不会使用或保存 Keychain 密码。
GPG 传递的 `allow-external-password-cache` 与 `SETKEYINFO` 是使用外部缓存的必要条件。

### 首次签名及指纹验证

```sh
echo test | gpg --clearsign > /dev/null
```

首次弹出密码输入框；如希望之后用指纹解锁，勾选 **Save in Keychain for Touch ID**。
以后在 gpg-agent 自己的缓存失效后，才会显示 Touch ID。
如果配置了很长的 `default-cache-ttl` / `max-cache-ttl`，不会每次签名都验证指纹。

为了人工验证完整流程，可以在两次签名之间执行：

```sh
gpgconf --kill gpg-agent
```

注意：这会清空该 agent 内**所有密钥**的内存缓存，可能影响正在使用 GPG/SSH agent 的其他程序。

### 删除缓存

在“钥匙串访问”中查找 service `pinentry-touchid.swift`，或使用：

```sh
pinentry-touchid --forget 'n/KEYGRIP'
```

参数必须是 GPG 传递的完整、不透明 `SETKEYINFO` 值，例如 `n/…` 或 `s/…`，而不是密码、短 Key ID 或邮箱。
程序不会读取、修改 Go 版或 `pinentry-mac` 创建的 `GnuPG` service 条目。

## 安全边界

- **Touch ID 验证在应用层执行。** 本实现先调用 LocalAuthentication，再通过 Security.framework 读取普通登录钥匙串条目。
- Keychain 条目本身没有设置 `SecAccessControl` 生物识别 ACL，**不是由系统强制每次取密码都必须指纹验证的存储方案**。钥匙串访问权限、登录钥匙串解锁状态及本机账户安全仍是基础保护。
- 密码保存在 Keychain，非 iCloud 同步；GPG 私钥仍由 GnuPG 管理，**没有导入 Secure Enclave**。
- Swift/AppKit 会产生密码在内存中的副本；输入控件在关闭后会清空，但无法保证所有副本都已擦除或从未被换出。
- SwiftPM 的 Apple Silicon 构建通常使用 ad-hoc 签名。替换或重新编译二进制可能再次触发 Keychain 授权。正式分发应使用稳定的代码签名身份；本项目没有自动配置签名或公证。
- 尚未完成安全审计，也不宣称与官方 pinentry 的安全内存实现等价。

## 协议支持与限制

支持 `OPTION`、`SETDESC`、`SETPROMPT`、`SETTITLE`、`SETOK`、`SETCANCEL`、`SETNOTOK`、
`SETERROR`、`SETREPEAT`、`SETREPEATERROR`、`SETKEYINFO`、`SETTIMEOUT`、`GETPIN`、
`CONFIRM`、`MESSAGE`、`RESET`、`NOP`、`BYE`、`GETINFO version|pid|flavor`。

缓存命中返回 `S PASSWORD_FROM_CACHE`；重复密码校验成功返回 `S PIN_REPEATED`。
忽略适用于其他前端的已知终端、locale、parent window 选项；未知命令或选项返回 Assuan 错误。

不支持密码质量条、密码生成、格式化、Emacs 集成或 pinentry 端的密码约束检查，相关选项/命令明确返回错误，而不是假装实现。

## 验证状态

已验证 release 构建、帮助/版本/Touch ID 能力查询，以及非交互协议和错误处理。
真实密码输入、Keychain 保存/读取和 Touch ID 成功/取消流程需要用户在本机交互验证；没有代读现有 GPG 密码。

当前未额外配置独立测试框架、lint hooks 或 CI。
