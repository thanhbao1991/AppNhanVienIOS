import SwiftUI

// Tông xanh navy chuyên nghiệp, khớp COLORS.primary của AppShippingIOS (src/theme.ts).
extension Color {
    static let brandPrimary = Color(red: 0x1E / 255, green: 0x4E / 255, blue: 0x8C / 255)
    static let textMuted = Color(red: 0x6C / 255, green: 0x75 / 255, blue: 0x7D / 255)
    static let successColor = Color(red: 0x19 / 255, green: 0x87 / 255, blue: 0x54 / 255)
    static let dangerColor = Color(red: 0xDC / 255, green: 0x35 / 255, blue: 0x45 / 255)
    static let warningColor = Color(red: 0xFF / 255, green: 0xC1 / 255, blue: 0x07 / 255)
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

    /// Viết tắt cho trục biểu đồ (vd "1807k").
    static func moneyShort(_ value: Double) -> String {
        "\(Int((value / 1000).rounded()))k"
    }

    private static let isoInFormats: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS"].map {
            let f = DateFormatter()
            f.dateFormat = $0
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }()

    static func parseIso(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        for f in isoInFormats {
            if let date = f.date(from: iso) { return date }
        }
        return nil
    }
}

extension String {
    /// So khớp không phân biệt hoa/thường, bỏ qua nil/rỗng — dùng cho mọi bộ lọc search client-side.
    /// Mặc định KHÔNG phân biệt dấu tiếng Việt (gõ "ca phe" vẫn khớp "Cà Phê").
    func matchesSearch(_ query: String, diacriticInsensitive: Bool = true) -> Bool {
        guard !query.isEmpty else { return true }
        var options: String.CompareOptions = [.caseInsensitive]
        guard diacriticInsensitive else { return range(of: query, options: options) != nil }
        options.insert(.diacriticInsensitive)
        // .diacriticInsensitive KHÔNG gộp "đ" về "d" (Unicode coi đ là chữ riêng) — tự đổi đ→d hai phía.
        return Self.boD(self).range(of: Self.boD(query), options: options) != nil
    }

    private static func boD(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
    }
}

func anyMatchesSearch(_ query: String, diacriticInsensitive: Bool = true, _ fields: String?...) -> Bool {
    guard !query.isEmpty else { return true }
    return fields.contains { $0?.matchesSearch(query, diacriticInsensitive: diacriticInsensitive) == true }
}
