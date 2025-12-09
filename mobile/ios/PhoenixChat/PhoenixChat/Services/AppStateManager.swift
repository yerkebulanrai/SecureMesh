import SwiftUI
internal import Combine

@MainActor
class AppStateManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // Пытаемся ТОЛЬКО ЗАГРУЗИТЬ. Если ключей нет — false.
        isAuthenticated = CryptoService.shared.loadKeys()
    }
    
    func logout() {
        // Явное удаление ключей через наш новый метод
        CryptoService.shared.clearKeys()
        isAuthenticated = false
    }
}
