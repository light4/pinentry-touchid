# 使用指南

[English](usage.md) | 简体中文

## 安装

GnuPG 需另行安装。Touch ID 需要兼容硬件及已登记的指纹，程序需要 macOS 本地图形会话。

### Homebrew

本仓库同时作为 tap 使用。由于仓库名不是 `homebrew-pinentry-touchid`，
添加 tap 时需要显式指定 URL：

```sh
brew tap light4/pinentry-touchid https://github.com/light4/pinentry-touchid
brew install light4/pinentry-touchid/pinentry-touchid
pinentry-touchid --check
```

Formula 从经过 SHA-256 校验的 `v0.1.0` release 源码压缩包构建。
要求 macOS 13+ 和 Swift 6+：macOS 15+ 使用 Xcode / Command Line Tools 的 Swift；
更早的 macOS 则依赖 Homebrew 的 Swift。
所选工具链及构建依赖也必须支持当前 macOS 版本。暂不提供预构建 bottle。

如需构建最新源码：

```sh
brew install --HEAD light4/pinentry-touchid/pinentry-touchid
```

打印用于 GPG 配置的稳定可执行文件路径：

```sh
printf '%s/bin/pinentry-touchid\n' "$(brew --prefix pinentry-touchid)"
```

### Nix

Nix 需启用 `nix-command` 与 `flakes` 实验特性。

```sh
nix profile add github:light4/pinentry-touchid
pinentry-touchid --check
```

Flake 为 `aarch64-darwin` 和 `x86_64-darwin` 提供
`packages.<system>.pinentry-touchid` 及 `default`。
锁定的 nixpkgs 当前要求 macOS 14+，不支持 Linux。

在工作副本中构建或运行，不安装到 profile：

```sh
nix build .
./result/bin/pinentry-touchid --check
nix run . -- --version
nix flake check
```

Nix 使用自己的编译器和 SDK，不依赖本机 Xcode。项目没有第三方依赖，
因此 derivation 使用 nixpkgs 的 Swift 5.10 直接编译 Swift 源文件，
不解析 Swift 6 的 SwiftPM manifest；构建时会对产物运行非 GUI E2E 检查。
`flake.lock` 锁定工具链和依赖。

GPG 应使用 profile 中稳定的绝对路径，通常为
`/Users/YOUR_USERNAME/.nix-profile/bin/pinentry-touchid`，
或 nix-darwin / Home Manager 管理的路径。
不要指向临时 `result` 软链接，也不要写死带版本的 `/nix/store/…` 路径。

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

**构建和包管理器安装都不会改动 GPG 配置。**
源码构建后可手动复制到固定位置（Homebrew / Nix 安装跳过此步）：

```sh
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

在 `~/.gnupg/gpg-agent.conf` 中设置 `pinentry-program`，替换已有的同名配置，使用完整绝对路径而不是 `~`：

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

Homebrew / Nix 安装请将示例替换为上文的稳定包路径；
除非准备自行管理更新，否则不要额外复制到 `~/bin`。

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
