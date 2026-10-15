# Usage guide

English | [简体中文](usage.zh-CN.md)

## Requirements and build

- macOS 13+; fingerprint authentication requires available Touch ID hardware and enrolled fingerprints.
- Swift 6+ / Xcode Command Line Tools.
- GnuPG must be installed separately.
- A local graphical session is required; no terminal fallback is implemented for headless SSH.

```sh
cd ~/sources/pinentry-touchid
swift build -c release
.build/release/pinentry-touchid --help
.build/release/pinentry-touchid --check
```

The executable is built at `.build/release/pinentry-touchid`.
`--check` only checks Touch ID availability; it does not display an authentication prompt or read a passphrase.

## Configure GPG

**Building does not install the program or modify GPG configuration.** You can manually copy it to a stable location:

```sh
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

Set `pinentry-program` in `~/.gnupg/gpg-agent.conf`, replacing any existing setting of the same name. Use a full absolute path, not `~`:

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

Then reload the agent:

```sh
gpg-connect-agent reloadagent /bye
```

If `no-allow-external-cache` is configured, Keychain passphrases will neither be used nor saved.
GPG must pass `allow-external-password-cache` and `SETKEYINFO` for external caching to work.

### First signing and fingerprint authentication

```sh
echo test | gpg --clearsign > /dev/null
```

The first request opens a passphrase dialog. Select **Save in Keychain for Touch ID** if you want to unlock it with your fingerprint later.
Subsequent requests prompt for Touch ID only after gpg-agent's own cache expires.
Long `default-cache-ttl` / `max-cache-ttl` values mean you will not be prompted for a fingerprint on every signing operation.

To manually verify the complete flow, you can run this between signing operations:

```sh
gpgconf --kill gpg-agent
```

Warning: this clears the agent's in-memory cache for **all keys** and may affect other programs using the GPG/SSH agent.

### Remove a cached passphrase

In Keychain Access, look for the service `pinentry-touchid.swift`, or run:

```sh
pinentry-touchid --forget 'n/KEYGRIP'
```

The argument must be the complete, opaque `SETKEYINFO` value passed by GPG, such as `n/…` or `s/…`, not a passphrase, short key ID, or email address.
The program does not read or modify entries under the `GnuPG` service created by the Go implementation or `pinentry-mac`.
