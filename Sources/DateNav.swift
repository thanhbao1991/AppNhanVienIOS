import SwiftUI

// Tách từ HoaDonListView để tái dùng cho các tab theo ngày/tháng khác (Thanh toán, Chi tiêu,
// 7 trang báo cáo) — khớp DateNavHelper.kt bên AppMobileAndroid.

enum DateNavFormat {
    static let queryDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()


    /// Chỉ Ngày/Tháng, bỏ năm — theo yêu cầu rút gọn UI (năm không cần thiết cho việc chọn nhanh).
    static let dayTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
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

/// Kích thước dùng chung cho MỌI thanh header đầu tab (DaySearchBar/DayDateBar) — ép cùng 1 chiều
/// cao bất kể tab đó có ô tìm kiếm hay không, để list bên dưới không nhảy vị trí khi chuyển tab.
enum HeaderBarMetrics {
    static let rowHeight: CGFloat = 38
    static let verticalPadding: CGFloat = 10
}

/// Gộp chọn ngày + ô tìm kiếm chung 1 dòng — thay cho DayNavBar+SearchBar 2 dòng riêng, bỏ hẳn 2 nút
/// chevron điều hướng (chỉ còn bấm vào ngày để mở DatePicker).
struct DaySearchBar: View {
    @Binding var date: Date
    @Binding var searchText: String
    var placeholder: String = "Tìm..."
    /// Nút phụ (vd "+") đặt bên trái cùng, trước nút ngày — tìm kiếm vẫn luôn ở giữa.
    var leading: AnyView? = nil
    /// Nút phụ (vd icon lọc nhanh) đặt bên phải cùng, sau ô tìm kiếm.
    var trailing: AnyView? = nil
    /// Tô nền gradient brandPrimary (khớp LoginView) + chữ nút ngày đổi trắng — đang thử nghiệm
    /// riêng cho tab Hoá đơn trước khi quyết định lan sang Thanh toán/Chi tiêu (2 tab còn lại
    /// cũng dùng chung component này).
    var tinted: Bool = false
    var onChange: () -> Void
    @State private var showPicker = false

    var body: some View {
        HStack(spacing: 8) {
            if let leading { leading }

            Button { showPicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(DateNavFormat.dayTitle.string(from: date))
                }
                .font(.subheadline.bold())
                .foregroundColor(tinted ? .white : .brandPrimary)
            }
            .buttonStyle(.plain)
            .fixedSize()

            SearchFieldRow(text: $searchText, placeholder: placeholder)

            if let trailing { trailing }
        }
        // Chiều cao cố định khớp DayDateBar (ThongKeView không có ô tìm kiếm nên hàng thấp hơn nếu
        // không ép cùng 1 giá trị) — lệch chiều cao 2 thanh header là nguyên nhân bị nháy/giật khi
        // chuyển qua lại giữa các tab (nội dung bên dưới nhảy vị trí theo).
        .frame(height: HeaderBarMetrics.rowHeight)
        .padding(.horizontal)
        .padding(.vertical, HeaderBarMetrics.verticalPadding)
        .background(
            Group {
                if tinted {
                    // ignoresSafeArea(.top) để gradient tô luôn phần status bar/tai thỏ phía trên,
                    // không dừng lại ngay dưới đó — chỉ áp cho lớp nền, nội dung (nút ngày/ô tìm
                    // kiếm) vẫn giữ nguyên vị trí trong safe area.
                    LinearGradient(colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .top)
                }
            }
        )
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Chọn ngày", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    // Chọn ngày (tap vào 1 ô) là đóng luôn, không cần bấm "Xong" nữa — chỉ đổi
                    // tháng/năm hiển thị trong lịch không kích hoạt vì chưa đổi giá trị `date`.
                    .onChange(of: date) { _ in
                        showPicker = false
                        onChange()
                    }
                Spacer()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
