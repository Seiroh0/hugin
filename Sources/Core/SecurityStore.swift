import Foundation
import Security

struct BookmarkRecord: Codable {
    let id: UUID
    let name: String
    let data: Data
}

final class SecurityStore: @unchecked Sendable {
    static let storageKey = "hugin.grants"
    private let defaults: UserDefaults
    private let service = "com.hugin.app"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    @discardableResult
    func addGrant(url: URL) throws -> Grant {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData()
        var records = Self.decode(defaults.data(forKey: Self.storageKey))
        guard !records.contains(where: { $0.name == url.lastPathComponent }) else {
            throw FileError.ioFailure("Ordner mit diesem Namen ist bereits freigegeben")
        }
        let grant = Grant(id: UUID(), name: url.lastPathComponent, url: url)
        records.append(BookmarkRecord(id: grant.id, name: grant.name, data: data))
        defaults.set(try JSONEncoder().encode(records), forKey: Self.storageKey)
        return grant
    }

    func loadGrants() -> (grants: [Grant], skipped: Int) {
        var grants: [Grant] = []
        var skipped = 0
        for record in Self.decode(defaults.data(forKey: Self.storageKey)) {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: record.data, relativeTo: nil,
                                     bookmarkDataIsStale: &stale), !stale else { skipped += 1; continue }
            // Zugriff bleibt bewusst für die App-Lebenszeit aktiv (ein start pro Grant, kein stop)
            _ = url.startAccessingSecurityScopedResource()
            grants.append(Grant(id: record.id, name: record.name, url: url))
        }
        return (grants, skipped)
    }

    private static func decode(_ data: Data?) -> [BookmarkRecord] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([BookmarkRecord].self, from: data)) ?? []
    }

    // MARK: Keychain (Claude-API-Key)
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "claude",
         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    }

    func saveKey(_ key: String) throws {
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw ModelError.network("Keychain-Fehler \(status)") }
    }

    func loadKey() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    func removeKey() { SecItemDelete(query as CFDictionary) }
}
