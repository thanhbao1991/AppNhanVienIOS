import SwiftUI
import UIKit

// Tông xanh navy chuyên nghiệp, khớp COLORS.primary của AppShippingIOS (src/theme.ts).
extension Color {
    static let brandPrimary = Color(red: 0x1E / 255, green: 0x4E / 255, blue: 0x8C / 255)
    static let textMuted = Color(red: 0x6C / 255, green: 0x75 / 255, blue: 0x7D / 255)
    static let successColor = Color(red: 0x19 / 255, green: 0x87 / 255, blue: 0x54 / 255)
    static let dangerColor = Color(red: 0xDC / 255, green: 0x35 / 255, blue: 0x45 / 255)
    static let warningColor = Color(red: 0xFF / 255, green: 0xC1 / 255, blue: 0x07 / 255)
    static let pinkColor = Color(red: 0xD6 / 255, green: 0x33 / 255, blue: 0x84 / 255)

    /// Trộn với trắng ra bản pastel đặc (không dùng opacity) — dùng làm nền card, giống cách Mobile
    /// web tô nền card bằng 1 màu pastel cố định thay vì border color mờ đi (opacity phụ thuộc nền
    /// phía sau, dễ ra xám/đậm khác ý muốn, nhất là dark mode).
    func pastelBackground(_ amount: CGFloat = 0.82) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func mix(_ c: CGFloat) -> CGFloat { c + (1 - c) * amount }
        return Color(red: mix(r), green: mix(g), blue: mix(b))
    }
}

/// Vòng loading toàn màn hình dùng chung mọi tab — mặc định ProgressView() màu xám hệ thống, kích
/// thước nhỏ, dễ tưởng app treo trên nền sáng (cùng feedback đã sửa bên AppDatHangIOS 2026-09-18:
/// "mờ lắm, cứ tưởng app bị treo"). Phóng to 1.4x + tint brandPrimary cho rõ ràng là đang tải.
func fullScreenLoading() -> some View {
    ProgressView()
        .scaleEffect(1.4)
        .tint(.brandPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

enum HoaDonFormatting {
    static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.locale = Locale(identifier: "vi_VN")
        f.maximumFractionDigits = 0
        return f
    }()

    static func money(_ value: Double) -> String {
        (moneyFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + "đ"
    }

    /// Viết tắt cho footer (vd "1807k") — không cần rõ số, chỉ cần ước lượng nhanh.
    static func moneyShort(_ value: Double) -> String {
        "\(Int((value / 1000).rounded()))k"
    }
}
