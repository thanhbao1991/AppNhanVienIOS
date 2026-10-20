import SwiftUI

/// Nút tài khoản dùng chung cho mọi tab — app không có tab "Tài khoản" riêng nên bấm 👤 hiện tên
/// đang đăng nhập + Đăng xuất (có xác nhận, tránh chạm nhầm).
struct AccountButton: View {
    @Binding var isLoggedIn: Bool
    var tint: Color = .primary
    @State private var showConfirm = false
    @State private var showNhapAnh = false

    var body: some View {
        Button { showConfirm = true } label: {
            Image(systemName: "person.crop.circle").font(.system(size: 22))
        }
        .buttonStyle(.plain)
        .foregroundColor(tint)
        .sheet(isPresented: $showNhapAnh) { NhapAnhView() }
        .confirmationDialog(Prefs.displayName ?? "Tài khoản", isPresented: $showConfirm, titleVisibility: .visible) {
            // TẠM THỜI (2026-10-20) — xem NhapAnhView.
            Button("Nhập ảnh từ máy quầy") { showNhapAnh = true }
            Button("Đăng xuất", role: .destructive) {
                Prefs.clear()
                Prefs.manualLogout = true
                isLoggedIn = false
            }
            Button("Huỷ", role: .cancel) {}
        }
    }
}
