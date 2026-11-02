import SwiftUI

/// App nhân viên có 5 tab (theo thứ tự): Thống kê (theo ngày), Ship, Chi tiêu, Lương (Nhã), Ảnh menu.
/// Chưa đăng nhập → LoginView; refresh token bị thu hồi (APIClient bắn .sessionExpired) → tự quay về LoginView.
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn
    @ObservedObject private var thongBao = ThongBaoBadge.shared

    var body: some View {
        Group {
            if isLoggedIn {
                TabView {
                    ThongKeView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Thống kê", systemImage: "chart.bar.xaxis") }
                    ShipView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Ship", systemImage: "bicycle") }
                    ChiTieuListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Chi tiêu", systemImage: "cart") }
                    TinhLuongView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Lương", systemImage: "banknote") }
                    SanPhamHinhAnhListView(isLoggedIn: $isLoggedIn)
                        .tabItem { Label("Ảnh menu", systemImage: "photo.on.rectangle.angled") }
                }
                // Phiên cũ còn hiệu lực lúc mở app, hoặc vừa đăng nhập xong → xin quyền + đăng ký push.
                .onAppear { PushNotifications.requestAndRegister() }
                .sheet(isPresented: $thongBao.moChuong) { ThongBaoListView() }
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .tint(.brandPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
    }
}
