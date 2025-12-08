//
//  PhoenixChatApp.swift
//  PhoenixChat
//
//  Created by Еркебулан Рай on 12/7/25.
//

import SwiftUI
import SwiftData

@main
struct PhoenixChatApp: App {
    // Наш менеджер состояния
    @StateObject private var appState = AppStateManager()
    
    // НАСТРОЙКА БАЗЫ ДАННЫХ
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MessageItem.self, // <-- Мы заменили Item.self на нашу модель
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(appState)
        }
        // Подключаем контейнер ко всему приложению
        .modelContainer(sharedModelContainer)
    }
}
