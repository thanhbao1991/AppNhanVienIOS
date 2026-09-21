import SwiftUI

struct ActionButtonView: View {
    /// Emoji thay cho SF Symbol (đổi 2026-09-12, khớp phong cách emoji đã dùng ở AppDatHangIOS).
    let icon: String
    let code: String?
    let caption: String
    let color: Color
    var prominent: Bool = false
    /// Nút phụ (không phải Tiền mặt/Chuyển khoản) co còn ~nửa kích thước, xếp 4 cột thay vì 2 —
    /// nhóm nút chính F1/F4 giữ nguyên cỡ lớn ở trên, phần còn lại chỉ cần bấm được, không cần to
    /// bằng 2 nút thu tiền chính (xem actionButtons()).
    var compact: Bool = false
    /// Nút không áp dụng cho hoá đơn hiện tại vẫn HIỂN THỊ (mờ đi) thay vì ẩn hẳn — giữ đúng vị trí
    /// cố định trong actionButtons(), tránh chỗ trống trong grid mà vẫn không bấm được.
    var disabled: Bool = false
    let action: () -> Void

    init(icon: String, code: String?, caption: String, color: Color, prominent: Bool = false, compact: Bool = false, disabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.code = code
        self.caption = caption
        self.color = color
        self.prominent = prominent
        self.compact = compact
        self.disabled = disabled
        self.action = action
    }

    private var label: some View {
        VStack(spacing: compact ? 0 : 1) {
            HStack(spacing: compact ? 2 : 4) {
                Text(icon)
                if let code {
                    Text(code).fontWeight(.bold)
                }
            }
            .font(compact ? .system(size: 11) : .footnote)
            Text(caption)
                .font(compact ? .system(size: 9) : .caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 2 : 4)
        // Emoji KHÔNG đổi màu theo .tint() như Image(systemName:) trước đây (glyph màu cố định) —
        // disabled=true trước đây tự mờ đi qua .tint(.gray), giờ phải tự thêm opacity mới thấy được
        // trạng thái "không bấm được", không thì icon emoji vẫn hiện sặc sỡ dù nút đang disabled.
        .opacity(disabled ? 0.4 : 1)
    }

    var body: some View {
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(disabled ? .gray : color)
                .disabled(disabled)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(disabled ? .gray : color)
                .disabled(disabled)
        }
    }
}
