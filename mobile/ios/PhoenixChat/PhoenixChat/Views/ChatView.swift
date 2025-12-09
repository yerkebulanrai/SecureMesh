import SwiftUI
import SwiftData // Импорт обязателен

struct ChatView: View {
    @StateObject var wsManager = WebSocketManager()
    
    // 1. Получаем доступ к базе данных
    @Environment(\.modelContext) private var context
    
    // 2. Волшебный запрос: "Дай мне все сообщения, отсортированные по дате"
    // Как только в базу упадет новое сообщение, этот массив обновится САМ.
    @Query(sort: \MessageItem.date, order: .forward) private var messages: [MessageItem]
    
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Статус бар
            HStack {
                Text(wsManager.isConnected ? "🟢 Онлайн" : "🔴 Офлайн")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                Spacer()
                // Кнопка очистки истории (для тестов)
                Button(action: deleteHistory) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            
            TextField("Вставь ID собеседника сюда", text: $wsManager.targetUserID)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption) // Сделаем поменьше, ID длинный
                                .onChange(of: wsManager.targetUserID) {_, _ in
                                    // Если ID изменился, пробуем обменяться ключами
                                    if wsManager.targetUserID.count > 10 {
                                        wsManager.connect() // Перезапуск шифрования
                                    }
                                }
            
            // Список сообщений
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Используем messages из @Query
                        ForEach(messages) { msg in
                            HStack {
                                if msg.isMe { Spacer() }
                                
                                VStack(alignment: msg.isMe ? .trailing : .leading) {
                                    Text(msg.text)
                                        .padding(12)
                                        .background(msg.isMe ? Color.blue : Color(uiColor: .secondarySystemBackground))
                                        .foregroundColor(msg.isMe ? .white : .primary)
                                        .cornerRadius(16)
                                    
                                    Text(msg.date.formatted(.dateTime.hour().minute()))
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                        .padding(.horizontal, 4)
                                }
                                
                                if !msg.isMe { Spacer() }
                            }
                            .padding(.horizontal)
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: messages) {_, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Поле ввода
            HStack(spacing: 10) {
                TextField("Сообщение...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(inputText.isEmpty || !wsManager.isConnected)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
        .onAppear {
            // 3. Самый важный момент: передаем контекст базы в менеджер!
            wsManager.modelContext = context
            wsManager.connect()
        }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        wsManager.sendProtoMessage(text: inputText)
        inputText = ""
    }
    
    // Функция очистки (если захочешь удалить все)
    func deleteHistory() {
        try? context.delete(model: MessageItem.self)
    }
}

#Preview {
    ChatView()
        .modelContainer(for: MessageItem.self, inMemory: true) // Для превью в памяти
}
