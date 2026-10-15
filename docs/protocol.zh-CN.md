# 协议支持与限制

[English](protocol.md) | 简体中文

支持 `OPTION`、`SETDESC`、`SETPROMPT`、`SETTITLE`、`SETOK`、`SETCANCEL`、`SETNOTOK`、
`SETERROR`、`SETREPEAT`、`SETREPEATERROR`、`SETKEYINFO`、`SETTIMEOUT`、`GETPIN`、
`CONFIRM`、`MESSAGE`、`RESET`、`NOP`、`BYE`、`GETINFO version|pid|flavor`。

缓存命中返回 `S PASSWORD_FROM_CACHE`；重复密码校验成功返回 `S PIN_REPEATED`。
忽略适用于其他前端的已知终端、locale、parent window 选项；未知命令或选项返回 Assuan 错误。

不支持密码质量条、密码生成、格式化、Emacs 集成或 pinentry 端的密码约束检查，相关选项/命令明确返回错误，而不是假装实现。

## 缓存与输入行为

- 通过 stdin/stdout 提供 pinentry Assuan 协议，支持 UTF-8、percent escaping 和长密码的分段数据响应。
- 支持 `SETTIMEOUT` / `--timeout`。
- GPG 报告密码错误时，删除对应旧缓存并重新询问；新建密码的重复输入流程不使用外部缓存。
- Touch ID 不可用或用户选择“Enter GPG Passphrase”时，使用原生密码输入。
- 取消或验证失败会返回错误，不自动读取密码，也不会自动改用密码输入绕过取消。

## 验证状态

已验证 release 构建、帮助/版本/Touch ID 能力查询，以及非交互协议和错误处理。
真实密码输入、Keychain 保存/读取和 Touch ID 成功/取消流程需要用户在本机交互验证；没有代读现有 GPG 密码。

已配置 prek hooks 与自动化黑盒 E2E 检查，详见[开发指南](development.zh-CN.md)。不包含单元测试，未配置 CI。原生弹窗超时检查需显式启用；成功输入密码及 Keychain / Touch ID 流程仍需人工验证。
