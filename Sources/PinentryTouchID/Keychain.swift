import Foundation
import Security

enum Keychain {
  // Deliberately isolated from pinentry-mac and the original Go implementation.
  static let service = "pinentry-touchid.swift"

  static func query(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecAttrSynchronizable as String: false,
    ]
  }

  static func contains(_ key: String) throws -> Bool {
    var request = query(key)
    request[kSecReturnAttributes as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    let status = SecItemCopyMatching(request as CFDictionary, nil)
    if status == errSecItemNotFound { return false }
    try check(status)
    return true
  }

  static func load(_ key: String) throws -> Data? {
    var request = query(key)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try check(status)
    guard let data = result as? Data else {
      throw PinentryError(1, "Unexpected Keychain result")
    }
    return data
  }

  static func save(_ data: Data, key: String) throws {
    let request = query(key)
    let status = SecItemUpdate(
      request as CFDictionary, [kSecValueData as String: data] as CFDictionary
    )
    if status == errSecItemNotFound {
      var item = request
      item[kSecValueData as String] = data
      item[kSecAttrLabel as String] = "GnuPG — " + key
      try check(SecItemAdd(item as CFDictionary, nil))
    } else {
      try check(status)
    }
  }

  static func delete(_ key: String) throws {
    let status = SecItemDelete(query(key) as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  private static func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
      throw PinentryError(1, "Keychain: " + message)
    }
  }
}
