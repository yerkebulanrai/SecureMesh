import Foundation
import CryptoKit

class CryptoService {
    static let shared = CryptoService()
    
    private(set) var privateKey: Curve25519.KeyAgreement.PrivateKey?
    private(set) var publicKey: Curve25519.KeyAgreement.PublicKey?
    
    // Ключ для сохранения в UserDefaults
    private let storageKey = "MyPrivateKey_V1"
    
    // 1. Генерация (или загрузка) ключей
    func generateKeys() {
        // Попробуем загрузить старый ключ, чтобы не терять личность
        if let savedData = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let restoredKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: savedData)
                self.privateKey = restoredKey
                self.publicKey = restoredKey.publicKey
                print("🔐 [Crypto] Ключи ВОССТАНОВЛЕНЫ из памяти!")
                print("🔐 [Crypto] Public Key: \(restoredKey.publicKey.rawRepresentation.base64EncodedString())")
                return
            } catch {
                print("⚠️ Ошибка восстановления ключа, генерируем новый.")
            }
        }
        
        // Если не нашли — генерируем новый
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        self.privateKey = privateKey
        self.publicKey = publicKey
        
        // Сохраняем навсегда
        saveKeyToStorage(privateKey)
        
        print("🔐 [Crypto] Сгенерированы НОВЫЕ ключи!")
    }
    
    private func saveKeyToStorage(_ key: Curve25519.KeyAgreement.PrivateKey) {
        let data = key.rawRepresentation
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    // 2. Получение публичного ключа строкой
    func getPublicKeyString() -> String? {
        guard let key = publicKey else { return nil }
        return key.rawRepresentation.base64EncodedString()
    }
    
    // 3. Вычисление общего секрета
    func deriveSharedSecret(remotePublicKeyString: String) throws -> SymmetricKey {
        guard let privateKey = self.privateKey else {
            throw NSError(domain: "Crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет приватного ключа"])
        }
        
        guard let data = Data(base64Encoded: remotePublicKeyString) else {
            throw NSError(domain: "Crypto", code: 2, userInfo: [NSLocalizedDescriptionKey: "Битый публичный ключ"])
        }
        let remoteKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: remoteKey)
        
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )
        return symmetricKey
    }
    
    // 4. Шифрование
    func encrypt(text: String, using key: SymmetricKey) throws -> Data {
        let data = Data(text.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combinedData = sealedBox.combined else {
             throw NSError(domain: "Crypto", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ошибка AES"])
        }
        return combinedData
    }
    
    // 5. Дешифровка
    func decrypt(combinedData: Data, using key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw NSError(domain: "Crypto", code: 4, userInfo: [NSLocalizedDescriptionKey: "Not a string"])
        }
        return text
    }
}
