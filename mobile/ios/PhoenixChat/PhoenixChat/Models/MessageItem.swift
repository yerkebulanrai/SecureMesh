import Foundation
import SwiftData

@Model
final class MessageItem {
    @Attribute(.unique) var id: UUID // Уникальный ID
    var text: String
    var isMe: Bool      // Мое или чужое
    var date: Date
    
    // Инициализатор для создания новых записей
    init(text: String, isMe: Bool, date: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.isMe = isMe
        self.date = date
    }
}
