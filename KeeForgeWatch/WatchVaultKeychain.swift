import Foundation
import Security

/// One Keychain item per database, holding its encoded snapshot.
///
/// `WhenPasscodeSetThisDeviceOnly`: the items never leave this Watch (no
/// backup, no migration), are readable only while it is unlocked, and cannot
/// exist at all on a Watch without a passcode — watchOS deletes them if the
/// passcode is turned off.
enum WatchVaultKeychain {
    private static let service = "at.kw.nextpass.watch.vault"

    enum Failure: Error, Equatable {
        /// The Watch is locked; retry once it is unlocked.
        case locked
        /// No passcode is set, so the data-protection class is unavailable.
        case noPasscode
        case status(OSStatus)
    }

    static func save(_ snapshot: WatchVaultSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try delete(databaseID: snapshot.databaseID)
        var query = baseQuery(account: snapshot.databaseID.uuidString)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        try check(SecItemAdd(query as CFDictionary, nil))
    }

    static func delete(databaseID: UUID) throws {
        let status = SecItemDelete(baseQuery(account: databaseID.uuidString) as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try check(status)
    }

    static func loadAll() throws -> [WatchVaultSnapshot] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return [] }
        try check(status)
        let items = result as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let data = item[kSecValueData as String] as? Data else { return nil }
            return try? JSONDecoder().decode(WatchVaultSnapshot.self, from: data)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func check(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess:
            return
        case errSecInteractionNotAllowed:
            throw Failure.locked
        case errSecNotAvailable, errSecAuthFailed:
            throw Failure.noPasscode
        default:
            throw Failure.status(status)
        }
    }
}
