# Protocol support and limitations

English | [简体中文](protocol.zh-CN.md)

Supported commands: `OPTION`, `SETDESC`, `SETPROMPT`, `SETTITLE`, `SETOK`, `SETCANCEL`, `SETNOTOK`,
`SETERROR`, `SETREPEAT`, `SETREPEATERROR`, `SETKEYINFO`, `SETTIMEOUT`, `GETPIN`,
`CONFIRM`, `MESSAGE`, `RESET`, `NOP`, `BYE`, and `GETINFO version|pid|flavor`.

Cache hits return `S PASSWORD_FROM_CACHE`; successful repeat-entry validation returns `S PIN_REPEATED`.
Known terminal, locale, and parent-window options intended for other frontends are ignored. Unknown commands or options return Assuan errors.

Passphrase quality bars, passphrase generation, formatting, Emacs integration, and pinentry-side passphrase constraint checks are not supported. Related options and commands explicitly return errors rather than pretending to implement these features.

## Cache and input behavior

- The pinentry Assuan protocol is served over stdin/stdout, with UTF-8, percent escaping, and chunked data responses for long passphrases.
- `SETTIMEOUT` / `--timeout` are supported.
- When GPG reports an incorrect passphrase, the corresponding old cache entry is deleted and the user is prompted again. Repeat-entry flows for new passphrases do not use external caching.
- When Touch ID is unavailable or the user chooses “Enter GPG Passphrase”, a native passphrase dialog is used.
- Cancellation or authentication failure returns an error. The program does not automatically read a passphrase or fall back to passphrase entry to bypass cancellation.

## Validation status

Release builds, help/version/Touch ID availability queries, and non-interactive protocol and error handling have been verified.
Actual passphrase entry, Keychain saving/retrieval, and Touch ID success/cancellation flows require interactive verification on the user's Mac. Existing GPG passphrases have not been read on the user's behalf.

[Development](development.md) documents the prek hooks and automated black-box E2E checks. No unit tests or CI are configured. Native dialog timeout checks are opt-in; successful passphrase entry and Keychain/Touch ID flows still require manual verification.
