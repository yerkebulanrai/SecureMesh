import Foundation

// Ошибки, которые могут возникнуть
enum NetworkError: Error {
    case badURL
    case serverError(String)
    case decodingError
}

// Сервис, отвечающий за авторизацию
// actor гарантирует потокобезопасность (Swift 6 Concurrency)
actor AuthService {
    // В симуляторе localhost работает нормально
    private let baseURL = "http://192.168.12.67:8080"
    
    func register(username: String, publicKey: String) async throws -> RegisterResponse {
        // 1. Формируем URL
        guard let url = URL(string: "\(baseURL)/register") else {
            throw NetworkError.badURL
        }
        
        // 2. Готовим запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Используем локальный DTO, чтобы гарантировать отсутствие изоляции конформанса
        struct RegisterPayload: Encodable, Sendable {
            let username: String
            let publicKey: String
            
            enum CodingKeys: String, CodingKey {
                case username
                case publicKey = "public_key"
            }
        }
        
        let body = RegisterPayload(username: username, publicKey: publicKey)
        request.httpBody = try JSONEncoder().encode(body)
        
        // 3. Отправляем (URLSession.shared.data - это async метод)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 4. Проверяем код ответа (201 Created)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Ошибка сервера или неверные данные")
        }
        
        // 5. Декодируем ответ через локальный тип, затем маппим в RegisterResponse
        struct LocalRegisterResponse: Decodable, Sendable {
            let status: String
            let userId: String
            
            enum CodingKeys: String, CodingKey {
                case status
                case userId = "user_id"
            }
        }
        
        do {
            let local = try JSONDecoder().decode(LocalRegisterResponse.self, from: data)
            return RegisterResponse(status: local.status, userId: local.userId)
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    // Новая структура ответа
    struct KeyResponse: Decodable, Sendable {
        let userId: String
        let publicKey: String
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case publicKey = "public_key"
        }
    }

    func fetchPublicKey(userID: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/keys/\(userID)") else {
            throw NetworkError.badURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Ключ не найден")
        }
        
        let result = try JSONDecoder().decode(KeyResponse.self, from: data)
        return result.publicKey
    }
}
