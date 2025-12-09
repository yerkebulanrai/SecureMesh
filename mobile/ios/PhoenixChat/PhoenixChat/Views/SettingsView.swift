import SwiftUI
import SwiftData // 1. Импортируем SwiftData

struct SettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    
    // 2. Получаем доступ к базе данных, чтобы удалять
    @Environment(\.modelContext) private var context
    
    var publicKeyInfo: String {
        CryptoService.shared.getPublicKeyString() ?? "Неизвестно"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Мой Аккаунт") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Пользователь SecureMesh")
                                .font(.headline)
                            Text("Онлайн")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading) {
                        Text("Мой Public Key")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(publicKeyInfo.prefix(20) + "...")
                            .font(.system(.body, design: .monospaced))
                    }
                    .contextMenu {
                        Button("Скопировать") {
                            UIPasteboard.general.string = publicKeyInfo
                        }
                    }
                }
                
                Section("Безопасность") {
                    Toggle("Face ID вход", isOn: .constant(false))
                    Toggle("Блокировка скриншотов", isOn: .constant(true))
                }
                
                // === КНОПКА ВЫХОДА ===
                Section {
                    Button(role: .destructive) {
                        performLogout()
                    } label: {
                        Text("Выйти из аккаунта")
                    }
                } footer: {
                    Text("При выходе ключи и история переписки будут безвозвратно удалены с устройства.")
                }
            }
            .navigationTitle("Настройки")
        }
    }
    
    // 3. Функция полного уничтожения данных
    func performLogout() {
            try? context.delete(model: MessageItem.self)
            
            // Удаляем ID из Keychain
            KeychainHelper.shared.delete(account: "my_user_id_v1")
            
            appState.logout() // Там внутри вызовется clearKeys() для приватного ключа
        }
}
