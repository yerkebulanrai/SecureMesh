import Foundation
import CryptoKit

class CryptoService {
    static let shared = CryptoService()
    
    private(set) var privateKey: Curve25519.KeyAgreement.PrivateKey?
    private(set) var publicKey: Curve25519.KeyAgreement.PublicKey?
    
    // Имя ячейки для хранения ключа
    private let keyAccountName = "my_private_key_v1"
    
    // 1. ЗАГРУЗКА (Ищем в облаке)
    func loadKeys() -> Bool {
        // Пробуем достать из Keychain
        if let savedData = KeychainHelper.shared.read(account: keyAccountName) {
            do {
                let restoredKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: savedData)
                self.privateKey = restoredKey
                self.publicKey = restoredKey.publicKey
                print("🔐 [Crypto] Ключи ВОССТАНОВЛЕНЫ из Keychain (iCloud)!")
                return true
            } catch {
                print("⚠️ Ошибка восстановления ключа (битые данные).")
            }
        }
        print("🔓 [Crypto] Ключей в Keychain нет.")
        return false
    }
    
    // 2. СОЗДАНИЕ НОВЫХ
    func createNewKeys() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
        
        // Сохраняем в Keychain!
        KeychainHelper.shared.save(privateKey.rawRepresentation, account: keyAccountName)
        print("✨ [Crypto] Новые ключи созданы и отправлены в iCloud.")
    }
    
    // 3. УДАЛЕНИЕ (Полный сброс)
    func clearKeys() {
        KeychainHelper.shared.delete(account: keyAccountName)
        self.privateKey = nil
        self.publicKey = nil
        print("💥 [Crypto] Ключи удалены из Keychain.")
    }
    
    // --- Остальные методы (без изменений) ---
    
    func getPublicKeyString() -> String? {
        guard let key = publicKey else { return nil }
        return key.rawRepresentation.base64EncodedString()
    }
    
    func deriveSharedSecret(remotePublicKeyString: String) throws -> SymmetricKey {
        guard let privateKey = self.privateKey else {
            throw NSError(domain: "Crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет приватного ключа"])
        }
        guard let data = Data(base64Encoded: remotePublicKeyString) else {
            throw NSError(domain: "Crypto", code: 2, userInfo: [NSLocalizedDescriptionKey: "Битый публичный ключ"])
        }
        let remoteKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: remoteKey)
        return sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
    }
    
    func encrypt(text: String, using key: SymmetricKey) throws -> Data {
        let data = Data(text.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combinedData = sealedBox.combined else {
             throw NSError(domain: "Crypto", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ошибка AES"])
        }
        return combinedData
    }
    
    func decrypt(combinedData: Data, using key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw NSError(domain: "Crypto", code: 4, userInfo: [NSLocalizedDescriptionKey: "Not a string"])
        }
        return text
    }
}
