import Foundation
import SwiftProtobuf
import CryptoKit
import SwiftData // <--- ВАЖНО: Импорт
internal import Combine

// ChatMessage struct нам больше НЕ НУЖЕН, мы используем MessageItem из SwiftData

@MainActor
class WebSocketManager: ObservableObject {
    private let urlString = "ws://192.168.12.67:8080/ws"
    
    // === ЖЕСТКАЯ ПРИВЯЗКА ID ===
    private static let userA = "bdfa964b-06ca-4a33-b128-76c63f9edb4f"
    private static let userB = "501c87ea-d2b1-437d-8b9b-2881faec0731"
    
    #if targetEnvironment(simulator)
        private let myUserID = WebSocketManager.userB
        private let targetUserID = WebSocketManager.userA
    #else
        private let myUserID = WebSocketManager.userA
        private let targetUserID = WebSocketManager.userB
    #endif

    private var webSocketTask: URLSessionWebSocketTask?
    private var sharedSessionKey: SymmetricKey?
    private let authService = AuthService()
    
    @Published var isConnected: Bool = false
    
    // === SWIFTDATA ===
    // Контекст базы данных. Мы передадим его из UI.
    var modelContext: ModelContext?
    
    func connect() {
        if CryptoService.shared.privateKey == nil {
            CryptoService.shared.generateKeys()
        }
        
        let fullURLString = "\(urlString)?userID=\(myUserID)"
        guard let url = URL(string: fullURLString) else { return }
        
        print("🔗 Подключаемся: \(fullURLString)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        self.isConnected = true
        listenForMessages()
        prepareEncryption()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.isConnected = false
    }
    
    private func prepareEncryption() {
        Task {
            do {
                print("🕵️‍♂️ Ищем публичный ключ собеседника...")
                let remoteKeyString = try await authService.fetchPublicKey(userID: targetUserID)
                self.sharedSessionKey = try CryptoService.shared.deriveSharedSecret(remotePublicKeyString: remoteKeyString)
                print("✅ E2EE Готово! Канал защищен.")
            } catch {
                print("❌ Ошибка E2EE Handshake: \(error)")
            }
        }
    }
    
    private func listenForMessages() {
        Task {
            do {
                while let task = webSocketTask, task.state == .running {
                    let message = try await task.receive()
                    switch message {
                    case .data(let data):
                        if let protoMsg = try? Securemesh_WebSocketMessage(serializedData: data) {
                            handleIncomingMessage(protoMsg)
                        }
                    default: break
                    }
                }
            } catch {
                print("❌ Disconnected: \(error)")
                self.isConnected = false
            }
        }
    }
    
    // === СОХРАНЕНИЕ В БАЗУ ===
    private func saveMessageToDB(text: String, isMe: Bool) {
        guard let context = modelContext else {
            print("⚠️ Ошибка: Context не установлен, сообщение не сохранено!")
            return
        }
        
        // Создаем объект SwiftData
        let newMessage = MessageItem(text: text, isMe: isMe, date: Date())
        
        // Вставляем в базу
        context.insert(newMessage)
        
        // Сохранять (context.save()) обычно не обязательно, SwiftData делает это автоматически,
        // но для надежности можно оставить на автопилоте.
        print("💾 Сообщение сохранено в телефон: \(text)")
    }
    
    private func handleIncomingMessage(_ msg: Securemesh_WebSocketMessage) {
        if msg.senderID == myUserID { return }
        guard let sessionKey = self.sharedSessionKey else { return }
        
        do {
            let decryptedText = try CryptoService.shared.decrypt(combinedData: msg.payload, using: sessionKey)
            print("📩 DECRYPTED: \(decryptedText)")
            
            // Сохраняем как "Чужое" (isMe: false)
            Task { @MainActor in
                self.saveMessageToDB(text: decryptedText, isMe: false)
            }
            
        } catch {
            print("⛔️ Ошибка: \(error)")
        }
    }
    
    func sendProtoMessage(text: String) {
        guard let sessionKey = self.sharedSessionKey else {
            print("⛔️ Ключи еще не готовы...")
            prepareEncryption()
            return
        }
        
        Task {
            do {
                let encryptedData = try CryptoService.shared.encrypt(text: text, using: sessionKey)
                
                var msg = Securemesh_WebSocketMessage()
                msg.type = .textMessage
                msg.id = UUID().uuidString
                msg.timestamp = Int64(Date().timeIntervalSince1970)
                msg.senderID = myUserID
                msg.recipientID = targetUserID
                msg.payload = encryptedData
                
                let binaryData = try msg.serializedData()
                let message = URLSessionWebSocketTask.Message.data(binaryData)
                try await webSocketTask?.send(message)
                
                print("📤 Отправлено: \(text)")
                
                // Сохраняем как "Свое" (isMe: true)
                Task { @MainActor in
                    self.saveMessageToDB(text: text, isMe: true)
                }
                
            } catch {
                print("❌ Ошибка отправки: \(error)")
            }
        }
    }
}
