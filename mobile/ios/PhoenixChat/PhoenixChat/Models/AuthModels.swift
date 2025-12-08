import Foundation

// Добавляем Sendable, чтобы разрешить передачу данных в actor
struct RegisterRequest: Encodable, Sendable {
    let username: String
    let publicKey: String
    
    enum CodingKeys: String, CodingKey {
        case username
        case publicKey = "public_key"
    }
}

// И здесь тоже добавляем Sendable
struct RegisterResponse: Decodable, Sendable {
    let status: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case userId = "user_id"
    }
}
