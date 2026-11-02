import SwiftUI
import UIKit
import UserNotifications

/// Chuông thông báo (đơn mới / sửa đơn / xoá đơn) — cùng nội dung với push, để xem lại push đã lỡ.
/// Đã xem tính RIÊNG từng máy (Prefs.thongBaoDaXemDen), KHÔNG gọi danh-dau-da-xem của backend: mốc đó
/// gắn với tài khoản, mà nhân viên dùng chung "ty" — máy này mở chuông sẽ xoá badge của máy khác.
@MainActor
final class ThongBaoBadge: ObservableObject {
    static let shared = ThongBaoBadge()
    @Published private(set) var soChuaXem = 0
    @Published var moChuong = false

    func refresh() async {
        guard Prefs.isLoggedIn, let list = await APIClient.shared.getThongBaoDon(take: 50) else { return }
        soChuaXem = list.filter { ThongBaoFormatting.moc($0.taoLuc) > Prefs.thongBaoDaXemDen }.count
    }

    func danhDauDaXem(_ moiNhat: ThongBaoNoiBoDto?) {
        if let moiNhat { Prefs.thongBaoDaXemDen = max(Prefs.thongBaoDaXemDen, ThongBaoFormatting.moc(moiNhat.taoLuc)) }
        soChuaXem = 0
    }
}

struct ThongBaoButton: View {
    @ObservedObject private var badge = ThongBaoBadge.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button { badge.moChuong = true } label: {
            Image(systemName: badge.soChuaXem > 0 ? "bell.badge" : "bell")
                .font(.system(size: 18))
                .overlay(alignment: .topTrailing) {
                    if badge.soChuaXem > 0 {
                        Text(badge.soChuaXem > 49 ? "50+" : "\(badge.soChuaXem)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(Color.red, in: Capsule())
                            .offset(x: 9, y: -7)
                    }
                }
        }
        .accessibilityLabel(badge.soChuaXem > 0 ? "Thông báo, \(badge.soChuaXem) chưa xem" : "Thông báo")
        // Sheet gắn 1 chỗ ở ContentView — nút này có mặt ở cả 4 tab, gắn ở đây sẽ mở chồng nhiều sheet.
        .task { await badge.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await badge.refresh() } }
        }
    }
}

struct ThongBaoListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ThongBaoNoiBoDto] = []
    @State private var hasLoaded = false
    @State private var loadFailed = false
    @State private var hasMore = true
    @State private var loadingMore = false
    /// Mốc "đã xem" lúc mở sheet — dòng mới hơn mốc này được tô đậm để biết cái nào vừa tới.
    @State private var daXemLucMo = Prefs.thongBaoDaXemDen

    private let pageSize = 50

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    List {
                        if items.isEmpty {
                            EmptyStateView(
                                symbol: loadFailed ? "wifi.exclamationmark" : "bell.slash",
                                title: loadFailed ? "Không tải được thông báo" : "Chưa có thông báo",
                                message: loadFailed ? "Kéo xuống để thử lại." : nil
                            )
                        }
                        ForEach(items) { item in
                            ThongBaoRowView(item: item, moi: ThongBaoFormatting.moc(item.taoLuc) > daXemLucMo)
                        }
                        if hasMore && !items.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .task(id: items.count) { await loadMore() }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Thông báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let first = await APIClient.shared.getThongBaoDon(take: pageSize)
        loadFailed = first == nil
        if let first {
            items = first
            hasMore = first.count >= pageSize
            ThongBaoBadge.shared.danhDauDaXem(first.first)
        }
        hasLoaded = true
    }

    private func loadMore() async {
        guard hasMore, !loadingMore, let last = items.last else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = await APIClient.shared.getThongBaoDon(take: pageSize, before: last.taoLuc) else { return }
        let known = Set(items.map(\.id))
        items.append(contentsOf: page.filter { !known.contains($0.id) })
        hasMore = page.count >= pageSize
    }
}

private struct ThongBaoRowView: View {
    let item: ThongBaoNoiBoDto
    let moi: Bool

    var body: some View {
        let style = ThongBaoFormatting.style(item.loai)
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: style.symbol, color: style.color, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ThongBaoFormatting.tieuDe(item.loai))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(ThongBaoFormatting.thoiGian(item.taoLuc))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if moi {
                        Circle().fill(Color.brandPrimary).frame(width: 8, height: 8)
                    }
                }
                Text(item.noiDung)
                    .font(.subheadline)
                    .fontWeight(moi ? .medium : .regular)
                    .foregroundColor(moi ? .primary : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum ThongBaoFormatting {
    /// Khớp MauThongBaoNoiBo.TieuDe bên Backend / ThongBaoNoiBoFormatting bên AppQuanLyIOS.
    static func tieuDe(_ loai: String) -> String {
        switch loai {
        case "HoaDonNew": return "Đơn mới"
        case "HoaDonNewShip": return "Đơn Ship"
        case "HoaDonNewMuaVe": return "Mua về"
        case "HoaDonNewTaiCho": return "Tại chỗ"
        case "HoaDonNewApp": return "Đơn App"
        case "HoaDonNewMuaHo": return "Mua hộ"
        case "HoaDonNewAppDatHang": return "App Đenn"
        case "HoaDonEdit": return "Sửa đơn"
        case "HoaDonDel": return "Xoá đơn"
        default: return "Thông báo"
        }
    }

    static func style(_ loai: String) -> (symbol: String, color: Color) {
        switch loai {
        case "HoaDonNew": return ("plus", .brandPrimary)
        case "HoaDonNewShip": return ("bicycle", .thongKeOrange)
        case "HoaDonNewMuaVe": return ("bag.fill", .thongKeTeal)
        case "HoaDonNewTaiCho": return ("cup.and.saucer.fill", .thongKeBrown)
        case "HoaDonNewApp": return ("iphone", .thongKePurple)
        case "HoaDonNewMuaHo": return ("hand.raised.fill", .thongKeGreen)
        case "HoaDonNewAppDatHang": return ("cart.fill", .thongKeBlue)
        case "HoaDonEdit": return ("pencil", .orange)
        case "HoaDonDel": return ("trash.fill", .thongKeRed)
        default: return ("bell.fill", .gray)
        }
    }

    /// Backend trả TaoLuc 7 chữ số lẻ giây ("2026-10-29T13:20:11.1234567") — so sánh theo 19 ký tự
    /// đầu (tới giây) là đủ và so chuỗi được luôn, khỏi parse.
    static func moc(_ iso: String) -> String { String(iso.prefix(19)) }

    static func thoiGian(_ iso: String) -> String {
        guard let date = HoaDonFormatting.parseIso(moc(iso)) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm dd/MM"
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: date)
    }
}

/// Cầu nối APNs — SwiftUI App không có hook nhận device token, phải qua UIApplicationDelegate.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Không có hàm này iOS im lặng nuốt push khi app đang mở.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await ThongBaoBadge.shared.refresh()
        return [.banner, .list, .sound]
    }

    // Bấm vào push → mở chuông.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { ThongBaoBadge.shared.moChuong = true }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { _ = await APIClient.shared.registerApnsDeviceToken(token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Đăng ký remote notification thất bại: \(error)")
    }
}

enum PushNotifications {
    /// Gọi mỗi khi vào trạng thái đã đăng nhập (login mới + mở app với phiên cũ) — token APNs có thể đổi.
    static func requestAndRegister() {
        guard !RuntimeEnv.isRunningUnitTests else { return }
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}
