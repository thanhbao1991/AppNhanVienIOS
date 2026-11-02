import SwiftUI

// Thành phần giao diện dùng chung mọi tab — phong cách native iOS (giống Cài đặt/Sức khoẻ): List
// insetGrouped trên nền systemGroupedBackground, tiêu đề lớn, SF Symbols trong ô vuông bo góc màu.

/// Ô vuông bo góc màu + SF Symbol trắng — kiểu icon từng dòng trong app Cài đặt.
struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
}

// MARK: - Chọn ngày / tháng

/// Thanh chọn ngày ghim dưới tiêu đề: ‹ Thứ Hai, 02/11 › — chạm vào ngày để mở lịch, có nút
/// "Hôm nay" khi đang xem ngày khác. Nền trùng nền List insetGrouped để liền một khối.
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
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Xong") { showPicker = false } }
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

private struct StepperBarLayout: View {
    let title: String
    let showReset: Bool
    let resetTitle: String
    let onPrev: () -> Void
    let onNext: () -> Void
    let onTitle: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("chevron.left", label: "Trước", action: onPrev)
            Spacer(minLength: 4)
            Button(action: onTitle) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.subheadline)
                    Text(title).font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            if showReset {
                Button(resetTitle, action: onReset)
                    .font(.footnote.weight(.semibold))
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
            Spacer(minLength: 4)
            stepButton("chevron.right", label: "Sau", action: onNext)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        // Nền đặc (không material) — material nhấp nháy khi List cuộn bên dưới.
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.15), value: showReset)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Thanh công cụ chung

extension View {
    /// Góc trái: tài khoản (tên + đăng xuất). Góc phải: chuông + nút riêng của tab (nếu có).
    func staffToolbar<Extra: View>(isLoggedIn: Binding<Bool>, @ViewBuilder extra: () -> Extra) -> some View {
        let extraView = extra()
        return toolbar {
            ToolbarItem(placement: .navigationBarLeading) { AccountMenu(isLoggedIn: isLoggedIn) }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ThongBaoButton()
                extraView
            }
        }
    }

    func staffToolbar(isLoggedIn: Binding<Bool>) -> some View {
        staffToolbar(isLoggedIn: isLoggedIn) { EmptyView() }
    }
}

extension String {
    /// "thứ hai, 02/11" → "Thứ hai, 02/11" (DateFormatter vi_VN viết thường chữ đầu).
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
