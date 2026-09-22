import SwiftUI

/// Thống kê theo NGÀY (không có thống kê tháng) — port từ ThongKeView của AppQuanLyIOS, cùng 7 endpoint
/// /api/ThongKe và cùng thứ tự/màu card với Desktop. Bản nhân viên chỉ XEM: chạm vào card để mở rộng
/// danh sách ngay tại chỗ, KHÔNG có drill-down sang hoá đơn/công nợ (những màn đó có thao tác thu tiền,
/// xoá... không thuộc phạm vi app nhân viên này).
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
    @State private var expandedCards: Set<ThongKeCard> = []

    /// Tiền mặt tại quán trừ chi tiêu ngày — số tiền mặt lẽ ra còn trong ngăn kéo. Port y hệt cách
    /// Desktop tự cộng dồn 2 API (không phải field riêng từ server).
    private var kiemTien: Double? {
        guard let tm = thanhToan?.danhSachTienMat.first?.soTien, let chi = chiTieu?.chiTieuNgay else { return nil }
        return tm - chi
    }

    var body: some View {
        AdaptiveNavigation {
            VStack(spacing: 0) {
                DayDateBar(
                    date: $currentDate,
                    trailing: AnyView(AccountButton(isLoggedIn: $isLoggedIn, tint: .white)),
                    tinted: true
                ) { Task { await load() } }

                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            // Thứ tự Y HỆT WrapPanel Desktop: Thanh toán, Doanh thu, Công nợ,
                            // Khách trả nợ, Chi tiêu, Chưa thanh toán, Tổng nợ.
                            if let thanhToan {
                                StatCard(icon: "💳", title: "Thanh toán", value: thanhToan.tongTienMat + thanhToan.tongChuyenKhoan, color: .thongKeBlue, isExpanded: expandedCards.contains(.thanhToan)) {
                                    toggle(.thanhToan)
                                } content: {
                                    ForEach(thanhToan.danhSachTienMat) { AmountRow(label: $0.ten, value: $0.soTien) }
                                    if thanhToan.tongChuyenKhoan > 0 {
                                        AmountRow(label: "Chuyển khoản", value: thanhToan.tongChuyenKhoan)
                                    }
                                    if let kiemTien {
                                        AmountRow(label: "Kiểm tiền", value: kiemTien, color: .thongKeBlue)
                                    }
                                }
                            }
                            if let doanhThu {
                                StatCard(icon: "📈", title: "Doanh thu", value: doanhThu.tongDoanhThu, color: .thongKeGreen, isExpanded: expandedCards.contains(.doanhThu)) {
                                    toggle(.doanhThu)
                                } content: {
                                    ForEach(doanhThu.danhSach) { AmountRow(label: $0.ten, value: $0.doanhThu) }
                                }
                            }
                            if let congNo {
                                StatCard(icon: "⚠️", title: "Công nợ", value: congNo.tongCongNoNgay, color: .thongKeBrown, isExpanded: expandedCards.contains(.congNo)) {
                                    toggle(.congNo)
                                } content: {
                                    ForEach(congNo.danhSachCongNoNgay) { AmountRow(label: $0.tenKhachHang, value: $0.soTienNo) }
                                }
                            }
                            if let traNo {
                                StatCard(icon: "✅", title: "Khách trả nợ", value: traNo.tongTraNoTaiQuan + traNo.tongTraNoShipper, color: .thongKePurple, isExpanded: expandedCards.contains(.traNo)) {
                                    toggle(.traNo)
                                } content: {
                                    SubTotalRow(label: "Trả nợ tại quán", value: traNo.tongTraNoTaiQuan, color: .thongKePurple)
                                    ForEach(traNo.traNoTaiQuan) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
                                    SubTotalRow(label: "Trả nợ shipper", value: traNo.tongTraNoShipper, color: .thongKePurple)
                                    ForEach(traNo.traNoShipper) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
                                }
                            }
                            if let chiTieu {
                                StatCard(icon: "💵", title: "Chi tiêu", value: chiTieu.chiTieuNgay + chiTieu.chiTieuThang, color: .thongKeRed, isExpanded: expandedCards.contains(.chiTieu)) {
                                    toggle(.chiTieu)
                                } content: {
                                    SubTotalRow(label: "Chi tiêu ngày", value: chiTieu.chiTieuNgay, color: .thongKeRed)
                                    ForEach(chiTieu.danhSachChiTieuNgay) { AmountRow(label: $0.ten, value: $0.soTien) }
                                    // "Tháng" ở đây = dòng đánh dấu Bill tháng của NGÀY này (cùng cách Desktop
                                    // cộng dồn), không phải thống kê cả tháng.
                                    SubTotalRow(label: "Chi tiêu tháng", value: chiTieu.chiTieuThang, color: .thongKeRed)
                                    ForEach(chiTieu.danhSachChiTieuThang) { AmountRow(label: $0.ten, value: $0.soTien) }
                                }
                            }
                            if let chuaThanhToan {
                                StatCard(icon: "🕐", title: "Chưa thanh toán", value: chuaThanhToan.tongChuaThanhToan, color: .thongKeTeal, isExpanded: expandedCards.contains(.chuaThanhToan)) {
                                    toggle(.chuaThanhToan)
                                } content: {
                                    ForEach(chuaThanhToan.danhSach) { AmountRow(label: $0.tenKhachHang, value: $0.soTien) }
                                }
                            }
                            if let tongNo {
                                StatCard(icon: "📊", title: "Tổng nợ", value: tongNo.tongConLai, color: .thongKeOrange, isExpanded: expandedCards.contains(.tongNo)) {
                                    toggle(.tongNo)
                                } content: {
                                    ForEach(tongNo.danhSach) { AmountRow(label: $0.tenKhachHang, value: $0.tongConLai) }
                                }
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await load() }
                }
            }
        }
        .task { await load() }
    }

    private func toggle(_ card: ThongKeCard) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCards.contains(card) { expandedCards.remove(card) } else { expandedCards.insert(card) }
        }
    }

    private func load() async {
        let cal = Calendar.current
        let ngay = cal.component(.day, from: currentDate)
        let thang = cal.component(.month, from: currentDate)
        let nam = cal.component(.year, from: currentDate)

        async let a = APIClient.shared.getThongKeChiTieu(ngay: ngay, thang: thang, nam: nam)
        async let b = APIClient.shared.getThongKeCongNo(ngay: ngay, thang: thang, nam: nam)
        async let c = APIClient.shared.getThongKeThanhToan(ngay: ngay, thang: thang, nam: nam)
        async let d = APIClient.shared.getThongKeDoanhThu(ngay: ngay, thang: thang, nam: nam)
        async let e = APIClient.shared.getThongKeTraNo(ngay: ngay, thang: thang, nam: nam)
        async let f = APIClient.shared.getThongKeDonChuaThanhToan(ngay: ngay, thang: thang, nam: nam)
        async let g = APIClient.shared.getTongNo()

        (chiTieu, congNo, thanhToan, doanhThu, traNo, chuaThanhToan, tongNo) = await (a, b, c, d, e, f, g)
        hasLoaded = true
    }
}

private enum ThongKeCard: Hashable {
    case thanhToan, doanhThu, congNo, traNo, chiTieu, chuaThanhToan, tongNo
}

/// Màu mỗi card lấy Y HỆT hex dùng trong AddRow() của ThongKeTabControl.xaml.cs (Desktop) — không
/// dùng warningColor (vàng) cho card nào, tránh Chi tiêu/Chưa thanh toán trùng màu "cảnh báo" gây
/// hiểu nhầm mức độ nghiêm trọng như nhau. Không đánh dấu private — ThongKeThangView tái dùng chung.
extension Color {
    static let thongKeBlue = Color(red: 0x0B / 255, green: 0x61 / 255, blue: 0xD6 / 255)
    static let thongKeGreen = Color(red: 0x0F / 255, green: 0x51 / 255, blue: 0x32 / 255)
    static let thongKeBrown = Color(red: 0x97 / 255, green: 0x4A / 255, blue: 0x05 / 255)
    static let thongKePurple = Color(red: 0x6D / 255, green: 0x28 / 255, blue: 0xD9 / 255)
    static let thongKeRed = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let thongKeTeal = Color(red: 0x03 / 255, green: 0x69 / 255, blue: 0xA1 / 255)
    static let thongKeOrange = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
}

/// Card tổng quan mỗi mục — cùng phong cách bo góc 14 + nền màu nhạt như HoaDonRowView/nút "+" của
/// tab Hoá đơn. Chạm vào header để mở rộng NGAY TẠI CHỖ (accordion) xem danh sách chi tiết, không
/// mở sheet riêng — chevron xoay theo trạng thái để báo hiệu có thể mở rộng. Không private —
/// ThongKeThangView tái dùng chung để giao diện khớp y hệt.
struct StatCard<Content: View>: View {
    let icon: String
    let title: String
    let value: Double
    var color: Color = .brandPrimary
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 30, height: 30)
                        // Emoji thay SF Symbol (đổi 2026-09-13) — emoji tự có màu riêng, không đổi
                        // theo .foregroundColor(color) như Image(systemName:) trước đây, nhưng vẫn
                        // giữ nền tròn màu color.opacity(0.15) phía sau cho nhất quán với thiết kế cũ.
                        Text(icon).font(.system(size: 15))
                    }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(HoaDonFormatting.money(value))
                        .font(.subheadline.bold())
                        .foregroundColor(color)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundColor(.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.horizontal, 12)
                    VStack(spacing: 4) {
                        content
                    }
                    .padding(12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

/// Hàng tổng phụ (vd "Chi tiêu ngày"/"Chi tiêu tháng", "Trả nợ tại quán"/"Trả nợ shipper") — khớp
/// các dòng bold "CHI TIÊU NGÀY"/"TRẢ NỢ TẠI QUÁN"... trong AddRow() Desktop, đứng trước danh sách
/// item con của nhóm đó.
struct SubTotalRow: View {
    let label: String
    let value: Double
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label).font(.footnote.weight(.bold)).foregroundColor(.secondary)
            Spacer()
            Text(HoaDonFormatting.money(value))
                .font(.footnote.weight(.bold))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .padding(.top, 4)
    }
}

struct AmountRow: View {
    let label: String
    var sub: String?
    let value: Double
    var color: Color = .primary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium))
                if let sub {
                    Text(sub).font(.caption).foregroundColor(.textMuted)
                }
            }
            Spacer()
            Text(HoaDonFormatting.money(value))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

