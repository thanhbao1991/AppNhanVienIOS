import SwiftUI

/// App nhân viên có 5 tab (theo thứ tự): Thống kê (theo ngày), Ship, Chi tiêu, Lương (Nhã), Ảnh menu.
/// Chưa đăng nhập → LoginView; refresh token bị thu hồi (APIClient bắn .sessionExpired) → tự quay về LoginView.
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn
    @ObservedObject private var thongBao = ThongBaoBadge.shared
    @ObservedObject private var dipLe = DipLe.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Màn chào dịp lễ (chỉ lúc mở app) — xem DipLe.swift, cùng cách AppQuanLyIOS.
    /// Có dịp lưu máy → hiện ngay từ khung hình đầu (không chờ server).
    @State private var manChao: DipLeTheme? = DipLe.themeLuuMay()

    var body: some View {
        ZStack {
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
            // Đổi dịp lễ (màu chủ đạo) → dựng lại toàn bộ để mọi màn ăn màu mới (Color.brandPrimary là static).
            .id(dipLe.phienBan)
            if let theme = manChao {
                DipLeManChaoView(theme: theme, tieuDe: dipLe.tieuDe, moTa: dipLe.moTa) { manChao = nil }
                    .zIndex(10)
            }
        }
        .task {
            // Đã có dịp lưu máy thì màn chào đang hiện sẵn — chỉ tải lại ngầm. Chưa có thì chỉ hiện nếu server trả
            // kịp ~1s; chậm hơn thì bỏ lần này, khỏi bật màn chào đè lúc đang dùng app.
            let daHienSan = manChao != nil
            let batDau = Date()
            await dipLe.load()
            if !daHienSan, Date().timeIntervalSince(batDau) < 1.0, let t = dipLe.active { manChao = t }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await dipLe.load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
    }
}
