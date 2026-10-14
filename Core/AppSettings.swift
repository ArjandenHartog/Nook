import Foundation
import Security

/// De API-sleutel staat in de Keychain, nooit in een bestand.
enum Keychain {
    static let service = "nl.imdigital.nook"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let keyAccount = "anthropic-api-key"

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "model") }
    }
    /// Nook kijkt zelf af en toe mee met het scherm. Standaard uit.
    @Published var autoWatch: Bool {
        didSet { UserDefaults.standard.set(autoWatch, forKey: "autoWatch") }
    }
    @Published private(set) var hasAPIKey: Bool

    private var cachedKey: String?
    var apiKey: String? { cachedKey }

    private init() {
        model = UserDefaults.standard.string(forKey: "model") ?? "claude-sonnet-5-5"
        autoWatch = UserDefaults.standard.bool(forKey: "autoWatch")
        let key = Keychain.read(Self.keyAccount)
        cachedKey = key
        hasAPIKey = !(key ?? "").isEmpty
    }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.write(trimmed, account: Self.keyAccount)
        cachedKey = trimmed.isEmpty ? nil : trimmed
        hasAPIKey = !trimmed.isEmpty
    }
}
