import Foundation

struct PinentryError: Error, LocalizedError {
  let code: Int
  let message: String
  init(_ code: Int, _ message: String) {
    self.code = code
    self.message = message
  }
  var errorDescription: String? { message }
  var assuanCode: Int { (5 << 24) | code }
}

struct Settings {
  var text: [String: String] = [:]
  var options: [String: String] = [:]
  var timeout: TimeInterval = 0
  var ok: String { text["SETOK"] ?? options["default-ok"] ?? "OK" }
  var cancel: String { text["SETCANCEL"] ?? options["default-cancel"] ?? "Cancel" }
  var prompt: String { text["SETPROMPT"] ?? options["default-prompt"] ?? "Passphrase" }
  var cacheKey: String? {
    guard options["allow-external-password-cache"] != nil,
      let key = text["SETKEYINFO"], !key.isEmpty, key != "--clear",
      text["SETREPEAT"] == nil
    else { return nil }
    return key  // Opaque identifier: do not parse descriptions or truncate keygrips.
  }
}

enum Assuan {
  static func decode(_ string: String) throws -> String {
    let bytes = Array(string.utf8)
    var output: [UInt8] = []
    var i = 0
    while i < bytes.count {
      if bytes[i] == 37 {
        guard i + 2 < bytes.count,
          let value = UInt8(String(decoding: bytes[(i + 1)...(i + 2)], as: UTF8.self), radix: 16)
        else { throw PinentryError(55, "Invalid percent escape") }
        guard value != 0 else { throw PinentryError(55, "NUL is not allowed") }
        output.append(value)
        i += 3
      } else {
        output.append(bytes[i])
        i += 1
      }
    }
    guard let result = String(bytes: output, encoding: .utf8) else {
      throw PinentryError(55, "Invalid UTF-8")
    }
    return result
  }

  static func encode(_ data: Data) -> String {
    data.map { byte in
      if byte < 32 || byte >= 127 || byte == 37 {
        return String(format: "%%%02X", byte)
      }
      return String(UnicodeScalar(byte))
    }.joined()
  }

  static func send(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
  }

  static func data(_ value: Data) {
    // Assuan lines must be below 1000 bytes, including prefix and newline.
    if value.isEmpty {
      send("D ")
      return
    }
    var offset = 0
    while offset < value.count {
      let end = min(offset + 240, value.count)
      send("D " + encode(value.subdata(in: offset..<end)))
      offset = end
    }
  }

  static func failure(_ error: PinentryError) {
    send("ERR \(error.assuanCode) " + encode(Data(error.message.utf8)))
  }
}

@MainActor
final class Server {
  var settings = Settings()
  private let setters: Set<String> = [
    "SETDESC", "SETPROMPT", "SETTITLE", "SETOK", "SETCANCEL", "SETNOTOK",
    "SETERROR", "SETREPEAT", "SETREPEATERROR", "SETKEYINFO",
  ]
  private let options: Set<String> = [
    "allow-external-password-cache", "ttyname", "ttytype", "lc-ctype", "lc-messages",
    "display", "parent-wid", "default-ok", "default-cancel", "default-notok",
    "default-prompt", "default-pwmngr", "default-cf-visi", "default-tt-visi",
    "default-tt-hide", "default-capshint", "grab", "no-grab", "touch-file",
    "owner", "invisible-char", "alert", "no-global-grab",
  ]

  func run() {
    Assuan.send("OK pinentry-touchid Swift ready")
    while let line = readLine() {
      if line.isEmpty || line.hasPrefix("#") { continue }
      do {
        guard line.utf8.count <= 65536 else { throw PinentryError(55, "Command too long") }
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else { continue }
        let command = String(first).uppercased()
        let argument = try Assuan.decode(parts.count > 1 ? String(parts[1]) : "")
        if command == "BYE" {
          Assuan.send("OK closing connection")
          return
        }
        try handle(command, argument)
        Assuan.send("OK")
      } catch let error as PinentryError {
        Assuan.failure(error)
      } catch {
        Assuan.failure(PinentryError(1, error.localizedDescription))
      }
    }
  }

  private func handle(_ command: String, _ argument: String) throws {
    if setters.contains(command) {
      settings.text[command] = argument
      return
    }
    switch command {
    case "OPTION":
      let parts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      let name = String(parts[0])
      guard options.contains(name) else { throw PinentryError(174, "Unknown option") }
      settings.options[name] = parts.count > 1 ? String(parts[1]) : ""
    case "SETTIMEOUT":
      guard let seconds = TimeInterval(argument), seconds.isFinite, seconds >= 0 else {
        throw PinentryError(55, "Invalid timeout")
      }
      settings.timeout = seconds
    case "GETPIN": try getPIN()
    case "CONFIRM", "MESSAGE":
      defer { settings.text.removeValue(forKey: "SETERROR") }
      try Dialogs.confirm(settings, oneButton: command == "MESSAGE" || argument == "--one-button")
    case "RESET":
      let options = settings.options
      let timeout = settings.timeout
      settings = Settings(options: options, timeout: timeout)
    case "NOP": break
    case "GETINFO":
      switch argument {
      case "version": Assuan.data(Data("0.1.0".utf8))
      case "pid": Assuan.data(Data(String(ProcessInfo.processInfo.processIdentifier).utf8))
      case "flavor": Assuan.data(Data("swift-touchid".utf8))
      default: throw PinentryError(55, "Unknown information request")
      }
    default: throw PinentryError(275, "Unknown command")
    }
  }

  private func getPIN() throws {
    defer { settings.text.removeValue(forKey: "SETERROR") }
    let key = settings.cacheKey
    let retry = !(settings.text["SETERROR"] ?? "").isEmpty
    if let key, !retry, Dialogs.touchIDAvailable,
      try Keychain.contains(key),
      try Dialogs.authenticate(timeout: settings.timeout),
      let password = try Keychain.load(key)
    {
      Assuan.send("S PASSWORD_FROM_CACHE")
      Assuan.data(password)
      return
    }
    // Never reuse a rejected cache entry. Do not cache passphrase creation/repeat prompts.
    if let key, retry { try Keychain.delete(key) }
    let (password, save) = try Dialogs.password(
      settings, maySave: key != nil && Dialogs.touchIDAvailable
    )
    if save, let key {
      do {
        try Keychain.save(password, key: key)
      } catch {
        try Dialogs.storageError(error, timeout: settings.timeout)
      }
    }
    if settings.text["SETREPEAT"] != nil { Assuan.send("S PIN_REPEATED") }
    Assuan.data(password)
  }
}
