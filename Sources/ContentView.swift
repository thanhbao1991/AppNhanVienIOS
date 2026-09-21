import SwiftUI

/// App nhân viên có 3 tab: Chi Tiêu, Thống kê (chỉ theo ngày), Ảnh menu. Chưa đăng nhập → LoginView;
/// refresh token bị thu hồi (APIClient bắn .sessionExpired) → tự quay về LoginView.
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn

    var body: some View {
        Group {
            if isLoggedIn {
                TabView {
                    ChiTieuListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Chi Tiêu", systemImage: "banknote") }
                    ThongKeView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Thống kê", systemImage: "chart.bar.fill") }
                    SanPhamHinhAnhListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Ảnh menu", systemImage: "photo.on.rectangle") }
                }
                .tint(.brandPrimary)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
    }
}
