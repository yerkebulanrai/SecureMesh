import SwiftUI
internal import Combine

@MainActor
class AppStateManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // Пытаемся восстановить ключи при запуске
        CryptoService.shared.generateKeys()
        
        // Если ключи успешно загрузились (они не nil) — значит мы авторизованы
        if CryptoService.shared.privateKey != nil {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
    
    func logout() {
        // Удаляем ключи (сброс личности)
        // В реальном проекте тут нужно чистить Keychain/UserDefaults надежнее
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        isAuthenticated = false
    }
}
