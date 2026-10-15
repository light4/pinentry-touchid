# pinentry-touchid (Swift)

English | [简体中文](README.zh-CN.md)

A native macOS GnuPG pinentry built with Swift, AppKit, LocalAuthentication, and Security.framework.
Inspired by [jorgelbg/pinentry-touchid](https://github.com/jorgelbg/pinentry-touchid), this is an independent implementation with no dependency on Go, Homebrew, or `pinentry-mac`.

- Native passphrase dialogs, repeat-entry validation, confirmations, and messages.
- Opt in to save a passphrase in Keychain, then authenticate with Touch ID to retrieve it.
- No passphrase or protocol logging; cancellation or authentication failure never triggers an automatic fallback that bypasses authentication.

## Quick start

Requires macOS 13+, Swift 6+ / Xcode Command Line Tools, and a separately installed GnuPG.
Touch ID requires compatible hardware and enrolled fingerprints. A local graphical session is required; there is no terminal fallback for headless SSH.

```sh
swift build -c release
.build/release/pinentry-touchid --check
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

Add or replace the following setting in `~/.gnupg/gpg-agent.conf`, using your own full absolute path:

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

```sh
gpg-connect-agent reloadagent /bye
```

Building does not install the program or modify GPG configuration. Select **Save in Keychain for Touch ID** when entering your passphrase to enable fingerprint unlocking later; GPG must allow external caching and supply `SETKEYINFO`. Touch ID is not prompted while gpg-agent's own cache remains valid.

**Security note:** Touch ID is enforced at the application layer, not by a biometric ACL on the Keychain item. Private keys remain managed by GnuPG, not stored in the Secure Enclave. This project has not undergone a security audit.

## Documentation

- [Usage guide](docs/usage.md): building, GPG configuration, first signing, Touch ID, and cache removal.
- [Security boundaries](docs/security.md): Keychain protection, memory limitations, and code signing.
- [Protocol support and limitations](docs/protocol.md): Assuan commands, compatibility, and validation status.
- [Development](docs/development.md): prek hooks and black-box E2E tests.
