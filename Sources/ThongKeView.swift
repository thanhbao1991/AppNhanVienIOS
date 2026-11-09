import SwiftUI

/// Thống kê theo NGÀY — cùng 7 endpoint /api/ThongKe và cùng số liệu với Desktop. Bản nhân viên chỉ
/// XEM: phần đầu là 3 số chính (Doanh thu, Thanh toán, Kiểm tiền), bên dưới mỗi mục là 1 dòng kiểu
/// Cài đặt, chạm để mở rộng danh sách chi tiết ngay tại chỗ.
struct ThongKeView: View {
    @Binding var isLoggedIn: Bool
    @State private var currentDate = Date()
    @State private var chiTieu: ThongKeChiTieuDto?
    @State private var congNo: ThongKeCongNoDto?
    @State private var thanhToan: ThongKeThanhToanDto?
    @State private var doanhThu: ThongKeDoanhThuNgayDto?
    @State private var traNo: ThongKeTraNoNgayDto?
    @State private var chuaThanhToan: ThongKeDonChuaThanhToanDto?
    @State private var tongNo: TongNoDto?
    @State private var hasLoaded = false
    /// Có ít nhất 1 API lỗi ở lượt tải gần nhất — hiện dòng "Thử lại" thay vì im lặng để mục biến mất.
    @State private var loadFailed = false
    /// Số thứ tự lượt `load()` — lượt cũ về sau lượt mới (đổi ngày nhanh) phải bị bỏ, không được ghi đè.
    @State private var loadGeneration = 0
    /// Ngày mà dữ liệu đang giữ thuộc về (yyyy-M-d).
    @State private var loadedKey = ""

    /// Tiền mặt tại quán trừ chi tiêu ngày — số tiền mặt lẽ ra còn trong ngăn kéo (Desktop tự cộng 2 API).
    private var kiemTien: Double? {
        guard let tm = thanhToan?.danhSachTienMat.first?.soTien, let chi = chiTieu?.chiTieuNgay else { return nil }
        return tm - chi
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    List {
                        if loadFailed {
                            Section { LoadErrorRow(text: "Chưa tải được một số mục") { Task { await load() } } }
                        }
                        Section { hero }
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        Section("Chi tiết") { detailRows }
                    }
                    .listStyle(.insetGrouped)
                    .nenApp()
                    .refreshable { await load() }
                }
            }
            // Ngày nằm giữa thanh trên (giữa tài khoản và chuông) — tiết kiệm chỗ (chủ quán 2026-11-08).
            .toolbar { ToolbarItem(placement: .principal) { DateStepperBar(date: $currentDate) { Task { await load() } } } }
            .navigationBarTitleDisplayMode(.inline)
            .staffToolbar(isLoggedIn: $isLoggedIn)
        }
        .task { await load() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Doanh thu").font(.subheadline).foregroundColor(.secondary)
                MoneyText(value: doanhThu?.tongDoanhThu ?? 0, font: .system(size: 34, weight: .bold, design: .rounded))
            }
            Divider()
            HStack(alignment: .top) {
                heroMetric("Thanh toán", (thanhToan?.tongTienMat ?? 0) + (thanhToan?.tongChuyenKhoan ?? 0), .thongKeBlue)
                Spacer()
                heroMetric("Kiểm tiền", kiemTien, .successColor)
                Spacer()
                heroMetric("Chi tiêu", chiTieu.map { $0.chiTieuNgay + $0.chiTieuThang }, .thongKeRed)
            }
        }
    }

    private func heroMetric(_ title: String, _ value: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value.map(HoaDonFormatting.money) ?? "—")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // Thứ tự Y HỆT WrapPanel Desktop: Thanh toán, Doanh thu, Công nợ, Khách trả nợ, Chi tiêu,
    // Chưa thanh toán, Tổng nợ.
    @ViewBuilder
    private var detailRows: some View {
        if let thanhToan {
            StatDisclosure(symbol: "creditcard.fill", title: "Thanh toán", value: thanhToan.tongTienMat + thanhToan.tongChuyenKhoan, color: .thongKeBlue) {
                ForEach(thanhToan.danhSachTienMat) { AmountRow(label: $0.ten, value: $0.soTien) }
                if thanhToan.tongChuyenKhoan > 0 {
                    AmountRow(label: "Chuyển khoản", value: thanhToan.tongChuyenKhoan)
                }
                // Khớp Desktop: Nạp Xu = tiền thật vào ngân hàng; Xu = khách trả bằng ví, không phải
                // tiền thật — cả 2 không nằm trong tổng/Kiểm tiền.
                if let napXu = thanhToan.tongNapXu, napXu > 0 {
                    AmountRow(label: "Nạp Xu", value: napXu)
                }
                if let xu = thanhToan.tongViXu, xu > 0 {
                    AmountRow(label: "Xu (ví khách)", value: xu, color: .secondary)
                }
                if let kiemTien {
                    AmountRow(label: "Kiểm tiền", value: kiemTien, color: .thongKeBlue, bold: true)
                }
            }
        }
        if let doanhThu {
            StatDisclosure(symbol: "chart.line.uptrend.xyaxis", title: "Doanh thu", value: doanhThu.tongDoanhThu, color: .thongKeGreen) {
                ForEach(doanhThu.danhSach) { AmountRow(label: $0.ten, value: $0.doanhThu) }
            }
        }
        if let congNo {
            StatDisclosure(symbol: "exclamationmark.circle.fill", title: "Công nợ", value: congNo.tongCongNoNgay, color: .thongKeBrown) {
                ForEach(congNo.danhSachCongNoNgay) { AmountRow(label: $0.tenKhachHang, value: $0.soTienNo) }
            }
        }
        if let traNo {
            StatDisclosure(symbol: "checkmark.circle.fill", title: "Khách trả nợ", value: traNo.tongTraNoTaiQuan + traNo.tongTraNoShipper, color: .thongKePurple) {
                AmountRow(label: "Tại quán", value: traNo.tongTraNoTaiQuan, bold: true)
                ForEach(traNo.traNoTaiQuan) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
                AmountRow(label: "Shipper", value: traNo.tongTraNoShipper, bold: true)
                ForEach(traNo.traNoShipper) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
            }
        }
        if let chiTieu {
            StatDisclosure(symbol: "cart.fill", title: "Chi tiêu", value: chiTieu.chiTieuNgay + chiTieu.chiTieuThang, color: .thongKeRed) {
                AmountRow(label: "Chi ngày", value: chiTieu.chiTieuNgay, bold: true)
                ForEach(chiTieu.danhSachChiTieuNgay) { AmountRow(label: $0.ten, value: $0.soTien) }
                // "Tháng" ở đây = dòng đánh dấu Bill tháng của NGÀY này, không phải cả tháng.
                AmountRow(label: "Bill tháng", value: chiTieu.chiTieuThang, bold: true)
                ForEach(chiTieu.danhSachChiTieuThang) { AmountRow(label: $0.ten, value: $0.soTien) }
            }
        }
        if let chuaThanhToan {
            StatDisclosure(symbol: "clock.fill", title: "Chưa thanh toán", value: chuaThanhToan.tongChuaThanhToan, color: .thongKeTeal) {
                ForEach(chuaThanhToan.danhSach) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
            }
        }
        if let tongNo {
            StatDisclosure(symbol: "tray.full.fill", title: "Tổng nợ", value: tongNo.tongConLai, color: .thongKeOrange) {
                ForEach(tongNo.danhSach) { AmountRow(label: $0.tenKhachHang, value: $0.tongConLai) }
            }
        }
    }

    private func load() async {
        let cal = Calendar.current
        let ngay = cal.component(.day, from: currentDate)
        let thang = cal.component(.month, from: currentDate)
        let nam = cal.component(.year, from: currentDate)
        loadGeneration += 1
        let generation = loadGeneration
        let key = "\(nam)-\(thang)-\(ngay)"

        // Sang ngày khác: số của ngày cũ không được ở lại trên màn (kể cả khi API ngày mới lỗi).
        // Cùng ngày (kéo refresh/thử lại): giữ số cũ, API nào lỗi thì mục đó không bị mất.
        if key != loadedKey {
            chiTieu = nil; congNo = nil; thanhToan = nil; doanhThu = nil
            traNo = nil; chuaThanhToan = nil; tongNo = nil
            hasLoaded = false
        }

        async let a = APIClient.shared.getThongKeChiTieu(ngay: ngay, thang: thang, nam: nam)
        async let b = APIClient.shared.getThongKeCongNo(ngay: ngay, thang: thang, nam: nam)
        async let c = APIClient.shared.getThongKeThanhToan(ngay: ngay, thang: thang, nam: nam)
        async let d = APIClient.shared.getThongKeDoanhThu(ngay: ngay, thang: thang, nam: nam)
        async let e = APIClient.shared.getThongKeTraNo(ngay: ngay, thang: thang, nam: nam)
        async let f = APIClient.shared.getThongKeDonChuaThanhToan(ngay: ngay, thang: thang, nam: nam)
        async let g = APIClient.shared.getTongNo()

        let r = await (a, b, c, d, e, f, g)
        guard generation == loadGeneration else { return }   // đã có lượt load mới hơn — bỏ kết quả cũ

        chiTieu = r.0 ?? chiTieu
        congNo = r.1 ?? congNo
        thanhToan = r.2 ?? thanhToan
        doanhThu = r.3 ?? doanhThu
        traNo = r.4 ?? traNo
        chuaThanhToan = r.5 ?? chuaThanhToan
        tongNo = r.6 ?? tongNo
        loadFailed = r.0 == nil || r.1 == nil || r.2 == nil || r.3 == nil || r.4 == nil
            || r.5 == nil || r.6 == nil
        loadedKey = key
        hasLoaded = true
    }
}

/// Dòng kiểu Cài đặt (icon màu + tên + số tiền), chạm để mở danh sách chi tiết ngay bên dưới.
private struct StatDisclosure<Content: View>: View {
    let symbol: String
    let title: String
    let value: Double
    let color: Color
    @ViewBuilder let content: Content
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            content
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: symbol, color: color)
                Text(title).foregroundColor(.primary)
                Spacer()
                MoneyText(value: value, font: .body.weight(.semibold), color: color)
            }
        }
    }
}

/// Màu từng mục lấy Y HỆT hex dùng trong ThongKeTabControl.xaml.cs (Desktop).
extension Color {
    static let thongKeBlue = Color(red: 0x0B / 255, green: 0x61 / 255, blue: 0xD6 / 255)
    static let thongKeGreen = Color(red: 0x0F / 255, green: 0x51 / 255, blue: 0x32 / 255)
    static let thongKeBrown = Color(red: 0x97 / 255, green: 0x4A / 255, blue: 0x05 / 255)
    static let thongKePurple = Color(red: 0x6D / 255, green: 0x28 / 255, blue: 0xD9 / 255)
    static let thongKeRed = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let thongKeTeal = Color(red: 0x03 / 255, green: 0x69 / 255, blue: 0xA1 / 255)
    static let thongKeOrange = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
}
