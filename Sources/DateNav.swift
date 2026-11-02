import SwiftUI

enum DateNavFormat {
    static let queryDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let dayTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        f.locale = Locale(identifier: "vi_VN")
        return f
    }()

    /// "thứ hai, 02/11" — dùng ở thanh chọn ngày (DateStepperBar).
    static let weekdayTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, dd/MM"
        f.locale = Locale(identifier: "vi_VN")
        return f
    }()

    static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/yyyy"
        f.locale = Locale(identifier: "vi_VN")
        return f
    }()
}

/// Chọn tháng/năm bằng 2 bánh xe — DatePicker chuẩn không có chế độ "chỉ tháng/năm".
struct MonthYearPickerSheet: View {
    @Binding var date: Date
    var onDone: () -> Void

    @State private var month: Int
    @State private var year: Int

    private static let months = Array(1...12)
    private let years: [Int]

    init(date: Binding<Date>, onDone: @escaping () -> Void) {
        self._date = date
        self.onDone = onDone
        let cal = Calendar.current
        _month = State(initialValue: cal.component(.month, from: date.wrappedValue))
        _year = State(initialValue: cal.component(.year, from: date.wrappedValue))
        let currentYear = cal.component(.year, from: Date())
        years = Array((currentYear - 5)...(currentYear + 1))
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Tháng", selection: $month) {
                    ForEach(Self.months, id: \.self) { m in
                        Text("Tháng \(m)").tag(m)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Năm", selection: $year) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Chọn tháng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { commit() }
                }
            }
        }
    }

    private func commit() {
        if let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) {
            date = newDate
        }
        onDone()
    }
}
