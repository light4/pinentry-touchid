import AppKit
import Foundation

@main
struct PinentryTouchID {
  @MainActor
  static func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--help"] || arguments == ["-h"] {
      print(
        """
        Usage: pinentry-touchid [--help | --version | --check | --forget KEYINFO]

        With no arguments, serve the GnuPG pinentry Assuan protocol on stdin/stdout.
        --check           Report Touch ID availability without prompting or reading secrets.
        --forget KEYINFO  Delete this implementation's Keychain entry for an opaque SETKEYINFO.
        --version         Print the version.

        Configure gpg-agent.conf with an absolute pinentry-program path.
        Password storage is opt-in in the native password dialog.
        """)
      return
    }
    if arguments == ["--version"] {
      print("pinentry-touchid (Swift) 0.1.0")
      return
    }
    if arguments == ["--check"] {
      let available = Dialogs.touchIDAvailable
      print(
        "Touch ID: "
          + (available ? "available" : "unavailable; native passphrase dialog will be used"))
      return
    }
    if arguments.count == 2 && arguments[0] == "--forget" {
      do {
        try Keychain.delete(arguments[1])
        print("Keychain entry removed (if present)")
      } catch { fail(error.localizedDescription) }
      return
    }
    // gpg-agent can pass terminal/locale parameters even for a GUI pinentry.
    let ignored: Set<String> = [
      "--display", "--ttyname", "--ttytype", "--lc-ctype", "--lc-messages", "--parent-wid",
    ]
    let server = Server()
    var index = 0
    while index < arguments.count {
      let parts = arguments[index].split(separator: "=", maxSplits: 1)
      let name = String(parts[0])
      guard ignored.contains(name) || name == "--timeout" else {
        fail("Unknown argument: " + name)
      }
      let value: String
      if parts.count == 2 {
        value = String(parts[1])
      } else {
        index += 1
        guard index < arguments.count else { fail("Missing value for " + name) }
        value = arguments[index]
      }
      if name == "--timeout" {
        guard let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 else {
          fail("Invalid timeout")
        }
        server.settings.timeout = seconds
      }
      index += 1
    }
    // Never write diagnostics or passphrases to logs; stdout belongs to Assuan.
    signal(SIGPIPE, SIG_IGN)
    server.run()
  }

  private static func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
  }
}
