# 使用指南

[English](usage.md) | 简体中文

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
