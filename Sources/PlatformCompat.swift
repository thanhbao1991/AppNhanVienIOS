import SwiftUI

/// Deployment target hạ 16.0 → 15.0 (2026-09-22) nhưng vẫn dùng NavigationStack/presentationDetents
/// (API chỉ có từ iOS 16) ở khắp nơi — gom fallback iOS 15 vào 1 chỗ thay vì lặp `if #available` ở
/// từng file. Trên máy chạy iOS 16+ hành vi giữ nguyên y hệt trước khi hạ target.
struct AdaptiveNavigation<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

/// Enum riêng thay cho `PresentationDetent` (kiểu đó tự nó chỉ tồn tại từ iOS 16, khai báo tham số
/// kiểu đó thôi là đã lỗi biên dịch dưới deployment target 15, dù có bọc `if #available` bên trong
/// thân hàm — availability check runtime không cứu được lỗi ở mức chữ ký kiểu compile-time).
enum CompatDetent {
    case medium
    case height(CGFloat)
}

extension View {
    /// No-op trên iOS 15 (sheet full-size như mặc định cũ trước iOS 16, không có detent nhỏ hơn).
    @ViewBuilder
    func compatPresentationDetents(_ detents: [CompatDetent]) -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents(Set(detents.map { detent -> PresentationDetent in
                switch detent {
                case .medium: return .medium
                case .height(let h): return .height(h)
                }
            }))
        } else {
            self
        }
    }

    @ViewBuilder
    func compatPresentationDragIndicator(visible: Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDragIndicator(visible ? .visible : .hidden)
        } else {
            self
        }
    }

    /// Tô nền navigation bar theo màu brand (`toolbarBackground`/`toolbarColorScheme` chỉ có từ iOS
    /// 16) — trên iOS 15 no-op, nav bar giữ màu mặc định hệ thống (khác biệt thẩm mỹ chấp nhận được
    /// để đổi lấy hạ deployment target, không đáng để dựng lại bằng UINavigationBarAppearance).
    @ViewBuilder
    func compatToolbarBrandBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(Color.brandPrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            self
        }
    }
}
