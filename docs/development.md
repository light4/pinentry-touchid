# Development

English | [简体中文](development.zh-CN.md)

## Tools and hooks

In addition to the [build requirements](usage.md#requirements-and-build), install
[prek](https://prek.j178.dev/), [uv](https://docs.astral.sh/uv/), and
[Ruff](https://docs.astral.sh/ruff/). The Swift toolchain must provide `swift format`.

```sh
brew install prek uv ruff
prek install
prek run --all-files
```

Hooks are configured in the native `prek.toml` file, which prek discovers automatically.
Basic file checks use prek's native `repo: builtin`; no external hook repository is fetched.
The remaining hooks run locally installed tools. This configuration requires prek,
not the Python `pre-commit` runner.

`prek install` installs this checkout's pre-commit hook. Each commit checks for large
files, merge conflicts, YAML errors, trailing whitespace, and missing final newlines;
runs Swift and Python lint/format checks; and builds the release binary for E2E tests.
Lint/format checks do not rewrite Swift or Python source. To format manually:

```sh
swift format format --in-place --recursive Package.swift Sources
ruff format scripts/e2e.py
```

No unit tests, test framework dependencies, or CI are added.

## Black-box E2E tests

`scripts/e2e.py` uses only the Python standard library and runs the real executable
as a subprocess. It does not import Swift internals or use mocks.

```sh
uv run scripts/e2e.py --help
uv run scripts/e2e.py
```

By default it builds the release executable, then checks:

- CLI help, version, Touch ID availability, and invalid arguments.
- Assuan greetings, EOF, BYE, comments, command casing, and GETINFO responses.
- Supported settings/options, UTF-8 percent-encoded input, and timeout arguments.
- Errors for unsupported features, malformed escaping, NUL, invalid UTF-8, and
  oversized commands, plus session recovery after each error.

To test an existing binary without rebuilding:

```sh
uv run scripts/e2e.py --binary .build/release/pinentry-touchid
```

### Optional native dialog checks

Run in a local macOS graphical session:

```sh
uv run scripts/e2e.py --gui
```

This also opens real passphrase, repeat-entry, confirmation, and message dialogs
and waits for their automatic timeouts. Do not interact with the dialogs.
It verifies timeout errors, recovery, and timeout persistence across RESET.
These checks are not run by the commit hook.

Neither mode supplies real passphrases, retrieves or modifies Keychain entries,
or changes GPG configuration. The Touch ID availability check does not authenticate.

### Manual checks

Successful passphrase entry, repeat-entry mismatch/success, saving to Keychain,
Touch ID success/cancellation/fallback, rejected-passphrase cache removal, and
actual GPG signing still require interactive verification. Follow the
[usage guide](usage.md#first-signing-and-fingerprint-authentication) using a
disposable test key rather than an existing private key. Remove its cached
passphrase afterward using the [cache removal instructions](usage.md#remove-a-cached-passphrase).
Automated E2E results do not establish that these manual flows passed.
