# 开发指南

[English](development.md) | 简体中文

## 工具与 hooks

除[构建要求](usage.zh-CN.md#要求与构建)外，还需安装
[prek](https://prek.j178.dev/)、[uv](https://docs.astral.sh/uv/) 和
[Ruff](https://docs.astral.sh/ruff/)。Swift 工具链需提供 `swift format`。

```sh
brew install prek uv ruff
prek install
prek run --all-files
```

Hooks 配置使用原生的 `prek.toml` 文件，prek 会自动发现，无需额外指定路径。
基础文件检查使用 prek 原生的 `repo: builtin`，不拉取外部 hook 仓库；
其余 hooks 调用本机已安装的工具。该配置需要 prek，不适用于 Python `pre-commit`。

`prek install` 为当前工作副本安装 pre-commit hook。每次提交会检查大文件、
合并冲突、YAML 错误、行尾空白及文件末尾换行，运行 Swift / Python lint 与格式检查，
并构建 release 二进制执行 E2E 测试。
lint / 格式检查不会改写 Swift 或 Python 源码；需要格式化时手动执行：

```sh
swift format format --in-place --recursive Package.swift Sources
ruff format scripts/e2e.py
```

不添加单元测试、测试框架依赖或 CI。

## 打包

`flake.nix` / `nix/package.nix` 构建 macOS 原生可执行文件，
并在 derivation 的检查阶段运行现有非 GUI E2E 脚本。
构建输入仅包含 Swift 源文件和该脚本，不包含本地构建产物。

```sh
nix flake check
nixfmt --check flake.nix nix/package.nix
brew style Formula/pinentry-touchid.rb
```

`Formula/pinentry-touchid.rb` 锁定不可变源码压缩包及校验值，
`head` 跟踪 `main`。发布源码变更时，需一起更新压缩包 revision、版本和校验值。
当前快照使用 commit `27abc8fc6817a2549f008eec0d3cfd351e9c6355`，不依赖 release tag。

按[安装指南](usage.zh-CN.md#homebrew)安装 Formula 后，运行其 CLI / 协议冒烟测试：

```sh
brew test light4/pinentry-touchid/pinentry-touchid
```

Formula 测试运行已安装的真实可执行文件，不是单元测试。
包安装和测试都不会修改 GPG 配置。

## 黑盒 E2E 测试

`scripts/e2e.py` 仅使用 Python 标准库，以子进程运行真实可执行文件，
不导入 Swift 内部实现，也不使用 mock。

```sh
uv run scripts/e2e.py --help
uv run scripts/e2e.py
```

默认先构建 release 可执行文件，再验证：

- CLI 帮助、版本、Touch ID 可用性及非法参数。
- Assuan 握手、EOF、BYE、注释、命令大小写及 GETINFO 响应。
- 支持的设置与选项、UTF-8 percent 编码输入及超时参数。
- 不支持的功能、非法转义、NUL、非法 UTF-8、超长命令的错误响应，
  以及每次错误后的会话恢复。

如需跳过构建，直接检查已有二进制：

```sh
uv run scripts/e2e.py --binary .build/release/pinentry-touchid
```

### 可选原生弹窗检查

在 macOS 本地图形会话中运行：

```sh
uv run scripts/e2e.py --gui
```

额外打开真实密码输入、重复输入、确认和消息弹窗，等待其自动超时关闭。
请勿操作弹窗。检查覆盖超时错误、超时后的恢复，以及 RESET 后保留超时设置。
提交 hook 不运行这些检查。

两种模式都不会提供真实密码、读取或修改 Keychain 条目，也不会修改 GPG 配置。
Touch ID 可用性检查不会触发认证。

### 人工验证

成功输入密码、重复输入不一致 / 成功、保存到 Keychain、Touch ID 成功 / 取消 /
密码回退、错误密码的缓存清理，以及实际 GPG 签名仍需交互验证。
按[使用指南](usage.zh-CN.md#首次签名及指纹验证)操作，建议使用一次性测试密钥，
而非现有私钥；完成后按[缓存清理说明](usage.zh-CN.md#删除缓存)删除测试密码缓存。
自动化 E2E 通过不代表这些人工流程已通过。
