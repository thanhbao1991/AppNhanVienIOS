import SwiftUI

/// App nhân viên có 4 tab (theo thứ tự): Thống Kê (chỉ theo ngày), Chi Tiêu, Tính Lương (Nhã), Ảnh Menu.
/// Chưa đăng nhập → LoginView; refresh token bị thu hồi (APIClient bắn .sessionExpired) → tự quay về LoginView.
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn

    var body: some View {
        Group {
            if isLoggedIn {
                TabView {
                    ThongKeView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Thống Kê", systemImage: "chart.bar.fill") }
                    ChiTieuListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Chi Tiêu", systemImage: "banknote") }
                    TinhLuongView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Tính Lương", systemImage: "person.text.rectangle") }
                    SanPhamHinhAnhListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Ảnh Menu", systemImage: "photo.on.rectangle") }
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
