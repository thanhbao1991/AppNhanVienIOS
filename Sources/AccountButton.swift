import SwiftUI

/// Menu tài khoản góc trái mọi tab — tên đang đăng nhập + Đăng xuất (có xác nhận, tránh chạm nhầm).
struct AccountMenu: View {
    @Binding var isLoggedIn: Bool
    @State private var showConfirm = false
    @State private var showNhapAnh = false

    var body: some View {
        Menu {
            Section(Prefs.displayName ?? "Tài khoản") {
                // TẠM THỜI (2026-10-20) — xem NhapAnhView.
                Button { showNhapAnh = true } label: {
                    Label("Nhập ảnh từ máy quầy", systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) { showConfirm = true } label: {
                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20))
                .foregroundColor(.white)   // thanh trên gradient
                .accessibilityLabel("Tài khoản")
        }
        .sheet(isPresented: $showNhapAnh) { NhapAnhView() }
        .confirmationDialog("Đăng xuất khỏi máy này?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                Task {
                    // Gỡ token trước khi xoá phiên — không thì máy đã đăng xuất vẫn nhận push đơn.
                    _ = await APIClient.shared.registerApnsDeviceToken(nil)
                    Prefs.clear()
                    Prefs.manualLogout = true
                    isLoggedIn = false
                }
            }
            Button("Huỷ", role: .cancel) {}
        }
    }
}
