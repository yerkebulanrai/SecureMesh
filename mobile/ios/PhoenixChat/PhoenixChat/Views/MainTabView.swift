import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // ТАБ 1: Чат (наш Secure Chat)
            ChatView()
                .tabItem {
                    Label("Чаты", systemImage: "message.fill")
                }
            
            // ТАБ 2: Контакты (Заглушка)
            ContactsView()
                .tabItem {
                    Label("Контакты", systemImage: "person.2.fill")
                }
            
            // ТАБ 3: Файлы (SecureMesh Storage - задел на будущее с MinIO)
            SecureStorageView()
                .tabItem {
                    Label("Сейф", systemImage: "lock.doc.fill")
                }
            
            // ТАБ 4: Настройки (Твой ID и выход)
            SettingsView()
                .tabItem {
                    Label("Профиль", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue) // Цвет активной иконки
    }
}

// --- Заглушки для новых экранов (можно вынести в отдельные файлы) ---

struct ContactsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                Text("Список контактов пуст")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Контакты")
        }
    }
}

struct SecureStorageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                Text("Зашифрованное хранилище")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Сейф")
        }
    }
}
