import SwiftUI
import UIKit

// Thành phần giao diện dùng chung mọi tab. 09/11/2026: theo style app khách (AppDatHangIOS Theme.swift +
// TaiKhoanUI.swift) — thanh trên gradient chéo màu chủ đạo → tối, chữ trắng; nền xám #F5F5F5; thẻ trắng
// bo 18 có bóng nhẹ; ô icon tô màu nhạt; nút chính gradient.

extension Color {
    /// Nền xám trung tính — cùng Theme.bg của app khách.
    static let appNen = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF5 / 255)
    /// Bản tối của màu chủ đạo (navy #1E4E8C → ~#15375F, khớp primaryDark app khách) — tính theo màu hiện tại
    /// để dịp lễ đổi màu thì gradient đổi theo.
    static var brandPrimaryDark: Color { brandPrimary.toiHon(0.7) }

    func toiHon(_ heSo: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r * heSo, green: g * heSo, blue: b * heSo)
    }
}

enum Brand {
    static let bo: CGFloat = 18
    /// Gradient chéo sáng→tối — thanh trên, nút chính, thanh lọc (cùng công thức Theme.primaryGradient app khách).
    static var gradient: LinearGradient {
        LinearGradient(colors: [.brandPrimary, .brandPrimaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// Thanh trên gradient chữ trắng — gắn vào nội dung gốc của mỗi NavigationStack (tab + sheet).
    /// Nút trên thanh phải tự tô trắng (.foregroundColor(.white)) vì app đặt .tint(.brandPrimary) toàn cục.
    func thanhTrenThuongHieu() -> some View {
        self
            .toolbarBackground(Brand.gradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// List/ScrollView trên nền xám #F5F5F5 (thay systemGroupedBackground).
    func nenApp() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.appNen)
    }

    /// 1 dòng List(.plain) thành 1 thẻ trắng riêng (cùng cardRow + cardBoxStyle app khách).
    func dongThe(dem: CGFloat = 12) -> some View {
        self
            .theTrang(dem: dem)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Thẻ trắng bo 18 có bóng nhẹ — khối cơ bản (cùng tkThe app khách).
    func theTrang(dem: CGFloat = 16) -> some View {
        self
            .padding(dem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Brand.bo, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
    }
}

/// Nút chính nền gradient (thay .borderedProminent) — cùng GradientProminentButtonStyle app khách.
struct GradientProminentButtonStyle: ButtonStyle {
    var danger = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(danger
                ? LinearGradient(colors: [.red, .red.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                : Brand.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

extension ButtonStyle where Self == GradientProminentButtonStyle {
    static var gradientProminent: GradientProminentButtonStyle { GradientProminentButtonStyle() }
}

/// Ô vuông bo góc tô màu nhạt + SF Symbol cùng màu — kiểu TKIcon app khách (trước: nền đặc chữ trắng kiểu Cài đặt).
struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// Số tiền canh phải, chữ số đều nhau (không nhảy khi đổi số).
struct MoneyText: View {
    let value: Double
    var font: Font = .body
    var color: Color = .primary

    var body: some View {
        Text(HoaDonFormatting.money(value))
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
    }
}

/// Dòng nhãn — số tiền trong danh sách chi tiết.
struct AmountRow: View {
    let label: String
    let value: Double
    var color: Color = .primary
    var bold = false

    var body: some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundColor(bold ? .primary : .secondary)
            Spacer()
            MoneyText(value: value, font: bold ? .subheadline.weight(.semibold) : .subheadline, color: color)
        }
    }
}

/// Màn trống giữa danh sách (iOS 16 chưa có ContentUnavailableView).
struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title).font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// Dòng báo lỗi tải trong List, có nút Thử lại.
struct LoadErrorRow: View {
    var text = "Chưa tải được dữ liệu"
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").foregroundColor(.orange)
            Text(text).font(.subheadline)
            Spacer()
            Button("Thử lại", action: onRetry).font(.subheadline.weight(.semibold))
        }
    }
}

func fullScreenLoading() -> some View {
    ProgressView()
        .controlSize(.large)
        .tint(.brandPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appNen)
}

// MARK: - Chọn ngày / tháng

/// Ô chọn ngày giữa thanh trên: "Thứ Hai, 02/11" — chạm để mở lịch, có nút về hôm nay khi đang xem ngày khác.
struct DateStepperBar: View {
    @Binding var date: Date
    var onChange: () -> Void
    @State private var showPicker = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        StepperBarLayout(
            title: DateNavFormat.weekdayTitle.string(from: date).capitalizedFirst,
            showReset: !isToday,
            resetTitle: "Hôm nay",
            onPrev: { shift(-1) },
            onNext: { shift(1) },
            onTitle: { showPicker = true },
            onReset: { date = Date(); onChange() }
        )
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Chọn ngày", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal)
                    .navigationTitle("Chọn ngày")
                    .navigationBarTitleDisplayMode(.inline)
                    .thanhTrenThuongHieu()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Xong") { showPicker = false }.foregroundColor(.white) }
                    }
                    .onChange(of: date) { _ in
                        showPicker = false
                        onChange()
                    }
                Spacer(minLength: 0)
            }
            .presentationDetents([.medium])
        }
    }

    private func shift(_ days: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: days, to: date) else { return }
        date = d
        onChange()
    }
}

/// Như DateStepperBar nhưng theo tháng.
struct MonthStepperBar: View {
    @Binding var date: Date
    var onChange: () -> Void
    @State private var showPicker = false

    private var isThisMonth: Bool { Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month) }

    var body: some View {
        StepperBarLayout(
            title: "Tháng " + DateNavFormat.monthTitle.string(from: date),
            showReset: !isThisMonth,
            resetTitle: "Tháng này",
            onPrev: { shift(-1) },
            onNext: { shift(1) },
            onTitle: { showPicker = true },
            onReset: { date = Date(); onChange() }
        )
        .sheet(isPresented: $showPicker) {
            MonthYearPickerSheet(date: $date) {
                showPicker = false
                onChange()
            }
            .presentationDetents([.height(280)])
        }
    }

    private func shift(_ months: Int) {
        guard let d = Calendar.current.date(byAdding: .month, value: months, to: date) else { return }
        date = d
        onChange()
    }
}

/// Ô ngày/tháng gọn đặt GIỮA thanh trên (ToolbarItem .principal) — đã bỏ 2 nút ‹ › (chủ quán 2026-11-08: "điều hướng
/// quá tốn không gian"). Chạm vào để mở lịch; đang xem ngày khác thì có nút quay về hôm nay.
private struct StepperBarLayout: View {
    let title: String
    let showReset: Bool
    let resetTitle: String
    let onPrev: () -> Void
    let onNext: () -> Void
    let onTitle: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTitle) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.footnote)
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                }
                // Viên trắng mờ trên thanh gradient (09/11/2026, theo style app khách).
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            if showReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.title3).foregroundColor(.white)
                }
                .accessibilityLabel(resetTitle)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showReset)
    }
}

// MARK: - Thanh công cụ chung

extension View {
    /// Góc trái: tài khoản (tên + đăng xuất). Góc phải: chuông + nút riêng của tab (nếu có).
    func staffToolbar<Extra: View>(isLoggedIn: Binding<Bool>, @ViewBuilder extra: () -> Extra) -> some View {
        let extraView = extra()
        return toolbar {
            ToolbarItem(placement: .navigationBarLeading) { AccountMenu(isLoggedIn: isLoggedIn).foregroundColor(.white) }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ThongBaoButton().foregroundColor(.white)
                extraView.foregroundColor(.white)
            }
        }
        .thanhTrenThuongHieu()
    }

    func staffToolbar(isLoggedIn: Binding<Bool>) -> some View {
        staffToolbar(isLoggedIn: isLoggedIn) { EmptyView() }
    }
}

extension String {
    /// "thứ hai, 02/11" → "Thứ hai, 02/11" (DateFormatter vi_VN viết thường chữ đầu).
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
