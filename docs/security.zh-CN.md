# 安全边界

[English](security.md) | 简体中文

- **Touch ID 验证在应用层执行。** 本实现先调用 LocalAuthentication，再通过 Security.framework 读取普通登录钥匙串条目。
- Keychain 条目本身没有设置 `SecAccessControl` 生物识别 ACL，**不是由系统强制每次取密码都必须指纹验证的存储方案**。钥匙串访问权限、登录钥匙串解锁状态及本机账户安全仍是基础保护。
- 密码保存在 Keychain，非 iCloud 同步；GPG 私钥仍由 GnuPG 管理，**没有导入 Secure Enclave**。
- Swift/AppKit 会产生密码在内存中的副本；输入控件在关闭后会清空，但无法保证所有副本都已擦除或从未被换出。
- SwiftPM 的 Apple Silicon 构建通常使用 ad-hoc 签名。替换或重新编译二进制可能再次触发 Keychain 授权。正式分发应使用稳定的代码签名身份；本项目没有自动配置签名或公证。
- 尚未完成安全审计，也不宣称与官方 pinentry 的安全内存实现等价。
