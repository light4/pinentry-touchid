# pinentry-touchid (Swift)

English | [简体中文](README.zh-CN.md)

A native macOS GnuPG pinentry built with Swift, AppKit, LocalAuthentication, and Security.framework.
Inspired by [jorgelbg/pinentry-touchid](https://github.com/jorgelbg/pinentry-touchid), this is an independent implementation with no dependency on Go, Homebrew, or `pinentry-mac`.

- Native passphrase dialogs, repeat-entry validation, confirmations, and messages.
- Opt in to save a passphrase in Keychain, then authenticate with Touch ID to retrieve it.
- No passphrase or protocol logging; cancellation or authentication failure never triggers an automatic fallback that bypasses authentication.

## Quick start

Install with **Homebrew**:

```sh
brew tap light4/pinentry-touchid https://github.com/light4/pinentry-touchid
brew install light4/pinentry-touchid/pinentry-touchid
```

Or with **Nix**:

```sh
nix profile add github:light4/pinentry-touchid
```

See the [usage guide](docs/usage.md) for macOS/toolchain requirements, source builds,
and the required GPG configuration. Neither installer changes GPG configuration.
GnuPG must be installed separately; a local graphical session is required.

Select **Save in Keychain for Touch ID** when entering your passphrase to enable fingerprint unlocking later; GPG must allow external caching and supply `SETKEYINFO`. Touch ID is not prompted while gpg-agent's own cache remains valid.

**Security note:** Touch ID is enforced at the application layer, not by a biometric ACL on the Keychain item. Private keys remain managed by GnuPG, not stored in the Secure Enclave. This project has not undergone a security audit.

## Documentation

- [Usage guide](docs/usage.md): Homebrew/Nix installation, source builds, GPG configuration, Touch ID, and cache removal.
- [Security boundaries](docs/security.md): Keychain protection, memory limitations, and code signing.
- [Protocol support and limitations](docs/protocol.md): Assuan commands, compatibility, and validation status.
- [Development](docs/development.md): prek hooks and black-box E2E tests.
