import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    // Это имя сервиса, по которому мы будем искать наши секреты
    private let service = "com.securemesh.app"
    
    // Сохранение данных (с синхронизацией!)
    func save(_ data: Data, account: String) {
        // Сначала удаляем старое значение, чтобы не было конфликтов
        delete(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // ВАЖНО: Разрешаем синхронизацию через iCloud
            kSecAttrSynchronizable as String: true,
            // Доступно, даже если телефон заблокирован (но после первой разблокировки)
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("☁️ [Keychain] Данные для \(account) сохранены в облаке!")
        } else {
            print("❌ [Keychain] Ошибка сохранения: \(status)")
        }
    }
    
    // Чтение данных
    func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Ищем везде (и локально, и в облаке)
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            return item as? Data
        }
        return nil
    }
    
    // Удаление
    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }
}
