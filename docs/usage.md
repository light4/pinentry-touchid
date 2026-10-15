# Usage guide

English | [简体中文](usage.zh-CN.md)

## Install

GnuPG must be installed separately. Touch ID requires compatible hardware and
enrolled fingerprints; the app needs a local macOS graphical session.

### Homebrew

This repository doubles as a tap. Specify its URL explicitly because it is not
named `homebrew-pinentry-touchid`:

```sh
brew tap light4/pinentry-touchid https://github.com/light4/pinentry-touchid
brew install light4/pinentry-touchid/pinentry-touchid
pinentry-touchid --check
```

The formula builds from the SHA-256-verified `v0.1.0` release source archive. It requires macOS 13+ and Swift 6+: on macOS 15+ it uses the Swift toolchain
from Xcode / Command Line Tools; on older macOS it depends on Homebrew's Swift.
The selected toolchain and any build dependencies must support your macOS version.
There are no prebuilt bottles.

To build the latest source instead:

```sh
brew install --HEAD light4/pinentry-touchid/pinentry-touchid
```

To print the stable executable path for GPG configuration:

```sh
printf '%s/bin/pinentry-touchid\n' "$(brew --prefix pinentry-touchid)"
```

### Nix

Enable the `nix-command` and `flakes` experimental features in your Nix installation.

```sh
nix profile add github:light4/pinentry-touchid
pinentry-touchid --check
```

The flake exposes `packages.<system>.pinentry-touchid` and `default` for
`aarch64-darwin` and `x86_64-darwin`. The pinned nixpkgs currently requires
macOS 14+. Linux is not supported.

To build or run from a checkout without installing into your profile:

```sh
nix build .
./result/bin/pinentry-touchid --check
nix run . -- --version
nix flake check
```

Nix uses its own compiler and SDK, not the host's Xcode installation. Because
the package has no third-party dependencies, the derivation compiles the Swift
sources directly with nixpkgs' Swift 5.10, without evaluating the Swift 6 SwiftPM
manifest. The build runs the non-GUI E2E checks against the resulting binary.
`flake.lock` pins the toolchain and dependencies.

For GPG, use a stable absolute path in your profile (usually
`/Users/YOUR_USERNAME/.nix-profile/bin/pinentry-touchid`) or your nix-darwin /
Home Manager managed path. Do not point GPG at a temporary `result` symlink or
hard-code a version-specific `/nix/store/…` path.

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

**Neither building nor package installation modifies GPG configuration.**
If you built from source, manually copy the binary to a stable location (skip
this step for Homebrew / Nix):

```sh
mkdir -p ~/bin
install -m 755 .build/release/pinentry-touchid ~/bin/pinentry-touchid
```

Set `pinentry-program` in `~/.gnupg/gpg-agent.conf`, replacing any existing setting of the same name. Use a full absolute path, not `~`:

```conf
pinentry-program /Users/YOUR_USERNAME/bin/pinentry-touchid
```

For Homebrew or Nix, replace the example with the stable package path described
above; do not copy the binary to `~/bin` unless you intend to manage updates manually.

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
