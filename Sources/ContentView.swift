import SwiftUI

/// App nhân viên chỉ có 1 màn hình: Chi tiêu. Chưa đăng nhập → LoginView; refresh token bị thu hồi
/// (APIClient bắn .sessionExpired) → tự quay về LoginView.
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn

    var body: some View {
        Group {
            if isLoggedIn {
                ChiTieuListView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
    }
}
