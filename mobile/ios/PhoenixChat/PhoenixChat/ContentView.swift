import SwiftUI
internal import Combine

// ViewModel регистрации
@MainActor
class RegistrationViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var statusMessage: String = ""
    @Published var isLoading: Bool = false
    
    private let authService = AuthService()
    
    func register() {
        guard !username.isEmpty else { return }
        
        isLoading = true
        statusMessage = "Генерация ключей..."
        
        Task {
            do {
                // 1. Генерируем ключи
                CryptoService.shared.generateKeys()
                
                // 2. Достаем публичный ключ
                guard let realPublicKey = CryptoService.shared.getPublicKeyString() else {
                    statusMessage = "Ошибка генерации ключей"
                    isLoading = false
                    return
                }
                
                // 3. Отправляем на сервер
                let response = try await authService.register(username: username, publicKey: realPublicKey)
                
                self.statusMessage = "Успех! ID: \(response.userId)"
                
                // === ПРИНТ ДЛЯ КОПИРОВАНИЯ ===
                print("\n==================================================")
                print("🆔 ВАШ НОВЫЙ USER ID: \(response.userId)")
                print("==================================================\n")
                // ==============================
                
            } catch {
                self.statusMessage = "Ошибка: \(error.localizedDescription)"
                print("❌ Ошибка регистрации: \(error)")
            }
            self.isLoading = false
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RegistrationViewModel()
    
    // Доступ к глобальному состоянию (чтобы переключиться на Табы)
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .shadow(radius: 10)
            
            Text("SecureMesh")
                .font(.largeTitle)
                .fontWeight(.heavy)
            
            Text("Анонимный. Защищенный.\nТвой.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            
            TextField("Придумайте никнейм", text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            Button(action: {
                viewModel.register()
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Создать аккаунт")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || viewModel.username.isEmpty)
            
            Text(viewModel.statusMessage)
                .font(.footnote)
                .foregroundStyle(viewModel.statusMessage.contains("Успех") ? .green : .red)
                .multilineTextAlignment(.center)
                .padding()
                .animation(.easeInOut, value: viewModel.statusMessage)
            
            Spacer()
            Spacer()
        }
        .padding()
        // Следим за успехом регистрации
        .onChange(of: viewModel.statusMessage) {_, newValue in
            if newValue.contains("Успех") {
                // Переключаем экран через 1 секунду
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        appState.isAuthenticated = true
                    }
                }
            }
        }
    }
}

#Preview {
    // Для превью создаем фейковый стейт
    ContentView()
        .environmentObject(AppStateManager())
}
