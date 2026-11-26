#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Black-box E2E checks against the real pinentry-touchid executable."""

import argparse
import os
import re
import secrets
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GREETING = "OK pinentry-touchid Swift ready"
CLOSING = "OK closing connection"


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def execute(
    argv: list[str], *, stdin: str = "", status: int = 0, timeout: float = 15
) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            argv,
            input=stdin,
            capture_output=True,
            check=True,
            text=True,
            encoding="utf-8",
            cwd=ROOT,
            timeout=timeout,
        )
    except subprocess.CalledProcessError as error:
        if error.returncode != status:
            raise AssertionError(
                f"{argv!r}: exit {error.returncode}, expected {status}\n"
                f"stdout: {error.stdout!r}\nstderr: {error.stderr!r}"
            ) from error
        return subprocess.CompletedProcess(
            argv, error.returncode, error.stdout, error.stderr
        )
    expect(status == 0, f"{argv!r}: succeeded, expected exit {status}")
    return result


def protocol(
    binary: str,
    commands: list[tuple[str, list[str]]],
    *,
    args: tuple[str, ...] = (),
) -> list[str]:
    result = execute(
        [binary, *args], stdin="\n".join(command for command, _ in commands) + "\n"
    )
    expected = [GREETING]
    for _, response in commands:
        expected.extend(response)
    actual = result.stdout.splitlines()
    expect(
        actual == expected, f"Protocol mismatch:\n{actual!r}\nexpected:\n{expected!r}"
    )
    expect(not result.stderr, f"Unexpected protocol stderr: {result.stderr!r}")
    return actual


def error(code: int, message: str) -> list[str]:
    return [f"ERR {(5 << 24) | code} {message}"]


def cli(binary: str) -> str:
    help_text = execute([binary, "--help"])
    expect("Usage: pinentry-touchid" in help_text.stdout, "Missing CLI usage")
    expect(not help_text.stderr, "Help wrote to stderr")
    short_help = execute([binary, "-h"])
    expect(short_help.stdout == help_text.stdout, "Help aliases disagree")
    expect(not short_help.stderr, "Short help wrote to stderr")
    version = execute([binary, "--version"])
    match = re.fullmatch(
        r"pinentry-touchid \(Swift\) (\d+\.\d+\.\d+)\n", version.stdout
    )
    expect(match is not None and not version.stderr, "Invalid version response")
    availability = execute([binary, "--check"])
    expect(
        availability.stdout
        in (
            "Touch ID: available\n",
            "Touch ID: unavailable; native passphrase dialog will be used\n",
        )
        and not availability.stderr,
        "Invalid Touch ID availability response",
    )
    for args, diagnostic in [
        (["--unknown"], "Unknown argument: --unknown"),
        (["--forget"], "Unknown argument: --forget"),
        (["--display"], "Missing value for --display"),
        (["--timeout"], "Missing value for --timeout"),
        *[
            ([f"--timeout={value}"], "Invalid timeout")
            for value in ("-1", "nan", "inf", "x")
        ],
    ]:
        result = execute([binary, *args], status=1)
        expect(not result.stdout, f"Invalid CLI arguments wrote to stdout: {args}")
        expect(result.stderr == diagnostic + "\n", f"Wrong diagnostic for {args}")
    return match[1]


def session(binary: str, version: str) -> None:
    protocol(binary, [("", []), ("# ignored comment", []), ("nop", ["OK"])])
    # The PID must be a real positive process ID, not a fixed placeholder.
    result = execute([binary], stdin="GETINFO pid\nBYE\n")
    expect(
        re.fullmatch(
            re.escape(GREETING) + r"\nD [1-9]\d*\nOK\n" + re.escape(CLOSING) + r"\n",
            result.stdout,
        )
        is not None
        and not result.stderr,
        "Invalid PID response",
    )
    protocol(
        binary,
        [
            ("GETINFO version", [f"D {version}", "OK"]),
            ("GETINFO flavor", ["D swift-touchid", "OK"]),
            ("BYE", [CLOSING]),
            ("INVALID_AFTER_BYE", []),
        ],
    )
    for args in [
        ("--timeout", "0"),
        ("--timeout=0.25",),
        ("--display=:0", "--ttyname", "/dev/ttys000", "--ttytype=xterm"),
        ("--lc-ctype", "UTF-8", "--lc-messages=C", "--parent-wid=123"),
    ]:
        protocol(binary, [("NOP", ["OK"]), ("BYE", [CLOSING])], args=args)


def settings(binary: str) -> None:
    commands = [
        (f"{name} Test%20%E4%B8%AD%E6%96%87%25%0Aline", ["OK"])
        for name in (
            "SETDESC",
            "SETPROMPT",
            "SETTITLE",
            "SETOK",
            "SETCANCEL",
            "SETNOTOK",
            "SETERROR",
            "SETREPEAT",
            "SETREPEATERROR",
            "SETKEYINFO",
        )
    ]
    commands.extend(
        (f"OPTION {option}", ["OK"])
        for option in (
            "allow-external-password-cache",
            "ttyname=/dev/ttys000",
            "ttytype=xterm",
            "lc-ctype=UTF-8",
            "lc-messages=C",
            "display=:0",
            "parent-wid=123",
            "default-ok=_OK",
            "default-cancel=_Cancel",
            "default-notok=No",
            "default-prompt=Passphrase",
            "default-pwmngr=Manager",
            "default-cf-visi=Show",
            "default-tt-visi=Show",
            "default-tt-hide=Hide",
            "default-capshint=Caps",
            "grab",
            "no-grab",
            "touch-file=/tmp/not-created-by-e2e",
            "owner=123",
            "invisible-char=*",
            "alert",
            "no-global-grab",
        )
    )
    commands.extend(
        (command, ["OK"])
        for command in (
            "SETTIMEOUT 0",
            "SETTIMEOUT 0.25",
            "SETKEYINFO --clear",
            "RESET",
            "NOP",
        )
    )
    commands.append(("BYE", [CLOSING]))
    # No GETPIN: even with a synthetic key, do not query or mutate Keychain.
    protocol(binary, commands)


def failures(binary: str) -> None:
    commands = [
        ("UNKNOWN", error(275, "Unknown command")),
        ("OPTION unknown=value", error(174, "Unknown option")),
        ("GETINFO unknown", error(55, "Unknown information request")),
        *[
            (f"SETTIMEOUT {value}", error(55, "Invalid timeout"))
            for value in ("-1", "nan", "inf", "x", "")
        ],
        *[
            (f"SETDESC {value}", error(55, "Invalid percent escape"))
            for value in ("%", "%0", "%GG")
        ],
        ("SETDESC %00", error(55, "NUL is not allowed")),
        ("SETDESC %FF", error(55, "Invalid UTF-8")),
        ("X" * 65537, error(55, "Command too long")),
        ("SETQUALITYBAR Quality", error(275, "Unknown command")),
        ("OPTION constraints-enforce", error(174, "Unknown option")),
    ]
    # Check recovery after every error, rather than starting a new process each time.
    protocol(
        binary,
        [item for command in commands for item in (command, ("NOP", ["OK"]))]
        + [("BYE", [CLOSING])],
    )


def gui(binary: str) -> None:
    for command in ("GETPIN", "CONFIRM", "CONFIRM --one-button", "MESSAGE"):
        protocol(
            binary,
            [
                ("SETTIMEOUT 0.25", ["OK"]),
                ("RESET", ["OK"]),  # Timeout must survive RESET.
                ("SETTITLE pinentry-touchid E2E — do not interact", ["OK"]),
                ("SETDESC This test dialog will close automatically.", ["OK"]),
                (command, error(62, "Timed out")),
                ("NOP", ["OK"]),
                ("BYE", [CLOSING]),
            ],
        )
    protocol(
        binary,
        [
            ("SETREPEAT Repeat passphrase", ["OK"]),
            ("GETPIN", error(62, "Timed out")),
            ("BYE", [CLOSING]),
        ],
        args=("--timeout=0.25",),
    )


def pasteboard(value: str | None = None) -> str:
    env = {**os.environ, "LANG": "en_US.UTF-8"}
    argv = ["pbpaste"] if value is None else ["pbcopy"]
    result = subprocess.run(
        argv,
        input=value,
        capture_output=True,
        check=True,
        text=True,
        encoding="utf-8",
        env=env,
        timeout=5,
    )
    return result.stdout


def system_events(script: str) -> str:
    try:
        result = subprocess.run(
            [
                "osascript",
                "-e",
                f'tell application "System Events"\n{script}\nend tell',
            ],
            capture_output=True,
            check=True,
            text=True,
            timeout=10,
        )
    except subprocess.CalledProcessError as error:
        raise AssertionError(f"System Events failed: {error.stderr.strip()}") from error
    return result.stdout.strip()


# Accessibility does not expose this CLI process's windows, so ask CoreGraphics.
WINDOWS_JXA = """
ObjC.import("CoreGraphics");
function run(argv) {
  const windows = ObjC.deepUnwrap(ObjC.castRefToObject(
    $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0)));
  return windows.filter((w) => w.kCGWindowOwnerPID === Number(argv[0])).length;
}
"""


def onscreen_windows(pid: int) -> int:
    result = subprocess.run(
        ["osascript", "-l", "JavaScript", "-e", WINDOWS_JXA, str(pid)],
        capture_output=True,
        check=True,
        text=True,
        timeout=10,
    )
    return int(result.stdout)


def paste(binary: str) -> None:
    # Cmd+V must reach the focused secure field and insert at the cursor.
    # Synthetic keystrokes require Accessibility permission.
    expect(
        system_events("UI elements enabled") == "true",
        "Grant Accessibility to this terminal in System Settings > Privacy & Security",
    )
    secret = "e2e-paste-" + secrets.token_hex(8)
    original = pasteboard()
    pasteboard(secret)
    process = subprocess.Popen(
        [binary],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        cwd=ROOT,
    )
    try:
        assert process.stdin is not None
        # No SETKEYINFO: never query or save Keychain entries.
        process.stdin.write(
            "SETTIMEOUT 15\n"
            "SETTITLE pinentry-touchid E2E — do not interact\n"
            "SETREPEAT Repeat passphrase\n"
            "GETPIN\n"
            "BYE\n"
        )
        process.stdin.flush()  # communicate() closes stdin later.
        deadline = time.monotonic() + 10
        while onscreen_windows(process.pid) == 0:
            expect(time.monotonic() < deadline, "Passphrase dialog did not appear")
            time.sleep(0.2)
        time.sleep(0.5)  # Let the dialog become key before typing.
        # The app activates itself. Type a prefix and paste in the passphrase field,
        # Tab to the repeat field and do the same, then submit.
        type_and_paste = 'keystroke "a"\nkeystroke "v" using command down\n'
        system_events(type_and_paste + "key code 48\n" + type_and_paste + "key code 36")
        stdout, stderr = process.communicate(timeout=20)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        pasteboard(original)
    expected = [
        GREETING,
        "OK",
        "OK",
        "OK",
        "S PIN_REPEATED",
        f"D a{secret}",
        "OK",
        CLOSING,
    ]
    actual = stdout.splitlines()
    expect(actual == expected, f"Paste mismatch:\n{actual!r}\nexpected:\n{expected!r}")
    expect(not stderr, f"Unexpected paste stderr: {stderr!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--binary",
        type=Path,
        help="test an existing executable instead of building the release binary",
    )
    parser.add_argument(
        "--gui",
        action="store_true",
        help="also open real dialogs to verify timeouts (requires a local macOS graphical session)",
    )
    parser.add_argument(
        "--paste",
        action="store_true",
        help="also drive a real dialog with Cmd+V via System Events (requires Accessibility permission; temporarily replaces the clipboard)",
    )
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("E2E checks require macOS")
    try:
        if args.binary is None:
            print("Building release executable…", flush=True)
            execute(["swift", "build", "-c", "release"], timeout=180)
        binary = str(
            (args.binary or ROOT / ".build/release/pinentry-touchid").resolve()
        )
        version = cli(binary)
        print("PASS CLI", flush=True)
        for name, check in [
            ("Assuan sessions", lambda: session(binary, version)),
            ("settings and UTF-8 escaping", lambda: settings(binary)),
            ("errors and session recovery", lambda: failures(binary)),
        ]:
            check()
            print(f"PASS {name}", flush=True)
        if args.gui:
            gui(binary)
            print("PASS native dialog timeouts", flush=True)
        else:
            print("SKIP native dialog timeouts (enable with --gui)", flush=True)
        if args.paste:
            paste(binary)
            print("PASS Cmd+V paste into secure fields", flush=True)
        else:
            print("SKIP Cmd+V paste (enable with --paste)", flush=True)
    except (AssertionError, OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
