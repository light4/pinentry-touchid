import AppKit
import LocalAuthentication

@MainActor
enum Dialogs {
  @MainActor
  private final class AuthenticationResult {
    var value: (Bool, Error?)?
  }

  static func prepare() {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
  }

  static func alert(_ settings: Settings) -> NSAlert {
    prepare()
    let alert = NSAlert()
    alert.messageText = settings.text["SETTITLE"] ?? "GnuPG — pinentry-touchid"
    alert.informativeText = [
      settings.text["SETERROR"], settings.text["SETDESC"],
    ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    return alert
  }

  static func label(_ value: String) -> String {
    // Assuan accelerator syntax: _X -> X, __ -> _.
    var result = ""
    var escaped = false
    for character in value {
      if character == "_" && !escaped {
        escaped = true
        continue
      }
      result.append(character)
      escaped = false
    }
    return result
  }

  static func run(_ alert: NSAlert, timeout: TimeInterval) throws -> NSApplication.ModalResponse {
    var timedOut = false
    let timer: Timer? =
      timeout > 0
      ? Timer(timeInterval: timeout, repeats: false) { _ in
        MainActor.assumeIsolated {
          timedOut = true
          NSApp.abortModal()
          alert.window.orderOut(nil)
        }
      } : nil
    if let timer { RunLoop.main.add(timer, forMode: .modalPanel) }
    defer { timer?.invalidate() }
    let response = alert.runModal()
    if timedOut { throw PinentryError(62, "Timed out") }
    return response
  }

  static func password(_ settings: Settings, maySave: Bool) throws -> (Data, Bool) {
    var settings = settings
    while true {
      let alert = alert(settings)
      alert.addButton(withTitle: label(settings.ok))
      alert.addButton(withTitle: label(settings.cancel))
      let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
      field.placeholderString = label(settings.prompt)
      let repeatField = NSSecureTextField(frame: field.frame)
      repeatField.placeholderString = label(settings.text["SETREPEAT"] ?? "Repeat passphrase")
      NSLayoutConstraint.activate([
        field.widthAnchor.constraint(equalToConstant: 360),
        field.heightAnchor.constraint(equalToConstant: 24),
        repeatField.widthAnchor.constraint(equalToConstant: 360),
        repeatField.heightAnchor.constraint(equalToConstant: 24),
      ])
      let save = NSButton(
        checkboxWithTitle: "Save in Keychain for Touch ID", target: nil, action: nil
      )
      save.state = .off
      var views: [NSView] = [field]
      if settings.text["SETREPEAT"] != nil { views.append(repeatField) }
      if maySave { views.append(save) }
      let stack = NSStackView(views: views)
      stack.orientation = .vertical
      stack.alignment = .leading
      stack.spacing = 10
      stack.frame = NSRect(x: 0, y: 0, width: 360, height: CGFloat(views.count * 34))
      alert.accessoryView = stack
      alert.window.initialFirstResponder = field
      defer {
        field.stringValue = ""
        repeatField.stringValue = ""
      }
      guard try run(alert, timeout: settings.timeout) == .alertFirstButtonReturn else {
        throw PinentryError(99, "Canceled")
      }
      if settings.text["SETREPEAT"] != nil && field.stringValue != repeatField.stringValue {
        settings.text["SETERROR"] =
          settings.text["SETREPEATERROR"]
          ?? "Passphrases do not match. Please try again."
        continue
      }
      return (Data(field.stringValue.utf8), maySave && save.state == .on)
    }
  }

  static func confirm(_ settings: Settings, oneButton: Bool) throws {
    let alert = alert(settings)
    alert.addButton(withTitle: label(settings.ok))
    if !oneButton {
      if let notOK = settings.text["SETNOTOK"] ?? settings.options["default-notok"] {
        alert.addButton(withTitle: label(notOK))
      }
      alert.addButton(withTitle: label(settings.cancel))
    }
    let response = try run(alert, timeout: settings.timeout)
    if response == .alertFirstButtonReturn { return }
    if alert.buttons.count == 3 && response == .alertSecondButtonReturn {
      throw PinentryError(114, "Not confirmed")
    }
    throw PinentryError(99, "Canceled")
  }

  static var touchIDAvailable: Bool {
    let context = LAContext()
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
      && context.biometryType == .touchID
  }

  // false means the user explicitly chose password fallback.
  // Cancellation and authentication failure never silently release a cached password.
  static func authenticate(timeout: TimeInterval) throws -> Bool {
    prepare()
    let context = LAContext()
    context.localizedFallbackTitle = "Enter GPG Passphrase"
    let result = AuthenticationResult()
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: "unlock the GnuPG passphrase in Keychain"
    ) { success, error in
      DispatchQueue.main.async { result.value = (success, error) }
    }
    let deadline = timeout > 0 ? Date().addingTimeInterval(timeout) : Date.distantFuture
    while result.value == nil {
      if Date() >= deadline {
        context.invalidate()
        throw PinentryError(62, "Timed out")
      }
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    defer { context.invalidate() }
    guard let (success, error) = result.value else {
      throw PinentryError(1, "Authentication failed")
    }
    if success { return true }
    if let error = error as? LAError, error.code == .userFallback { return false }
    throw PinentryError(99, "Touch ID canceled or authentication failed")
  }

  static func storageError(_ error: Error, timeout: TimeInterval) throws {
    let alert = NSAlert()
    alert.messageText = "Passphrase was not saved"
    alert.informativeText =
      error.localizedDescription
      + "\nThis operation can continue; next time, enter the passphrase again."
    alert.addButton(withTitle: "OK")
    _ = try run(alert, timeout: timeout)
  }
}
