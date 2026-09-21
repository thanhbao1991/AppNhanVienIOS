import SwiftUI

/// Nút tài khoản dùng chung cho mọi tab — app không có tab "Tài khoản" riêng nên bấm 👤 hiện tên
/// đang đăng nhập + Đăng xuất (có xác nhận, tránh chạm nhầm).
struct AccountButton: View {
    @Binding var isLoggedIn: Bool
    var tint: Color = .primary
    @State private var showConfirm = false

    var body: some View {
        Button { showConfirm = true } label: {
            Text("👤").font(.system(size: 20))
        }
        .buttonStyle(.plain)
        .foregroundColor(tint)
        .confirmationDialog(Prefs.displayName ?? "Tài khoản", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                Prefs.clear()
                Prefs.manualLogout = true
                isLoggedIn = false
            }
            Button("Huỷ", role: .cancel) {}
        }
    }
}
