import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    
    // Получаем ID из CryptoService (или сохраняем его где-то отдельно)
    // Пока возьмем публичный ключ как идентификатор для красоты
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
                    
                    // Показываем ключ (или ID)
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
                
                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Text("Выйти из аккаунта")
                    }
                } footer: {
                    Text("При выходе ключи шифрования будут удалены с устройства. Историю переписки восстановить будет невозможно.")
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
