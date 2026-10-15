# Security boundaries

English | [简体中文](security.zh-CN.md)

- **Touch ID authentication is enforced at the application layer.** This implementation calls LocalAuthentication first, then reads an ordinary login Keychain item through Security.framework.
- Keychain items do not have a `SecAccessControl` biometric ACL. **The system does not enforce fingerprint authentication on every passphrase retrieval.** Keychain access permissions, the login Keychain's lock state, and local account security remain the underlying protections.
- Passphrases are stored in Keychain without iCloud synchronization. GPG private keys remain managed by GnuPG and **are not imported into the Secure Enclave**.
- Swift/AppKit creates in-memory copies of passphrases. Input controls are cleared when closed, but there is no guarantee that all copies have been erased or have never been swapped out.
- SwiftPM builds on Apple Silicon typically use ad-hoc signing. Replacing or rebuilding the binary may trigger Keychain authorization again. Distribution should use a stable code-signing identity; this project does not automatically configure signing or notarization.
- This project has not undergone a security audit and does not claim equivalence to the secure-memory implementation of official pinentry.
