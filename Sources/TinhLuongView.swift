import Charts
import SwiftUI

/// Tính lương Nhã — không lưu gì lên server, chỉ đọc chi ứng của Nhã trong tháng
/// (GET /api/ThongKe/luong-shipper-thang). Lương hiện tại là ô nhập tại chỗ để thử nhiều kịch bản.
/// Công thức: Còn nhận = Lương hiện tại − Ứng.
struct TinhLuongView: View {
    @Binding var isLoggedIn: Bool
    private let shipperTen = "Nhã"

    @State private var currentDate = Date()
    @State private var luong: LuongShipperDto?
    @State private var chiTieuMonthItems: [ChiTieuHangNgayDto] = []
    @State private var hasLoaded = false
    @State private var luongHienTaiText = Self.formatThousands("10000000")
    @State private var showUngDetail = false
    /// Dữ liệu thô 6 tháng gần đây (kết thúc ở currentDate) — giữ raw để biểu đồ tự cập nhật theo
    /// lương hiện tại đang gõ.
    @State private var luong6ThangRaw: [(thang: Int, nam: Int, luong: LuongShipperDto)] = []
    @FocusState private var luongFocused: Bool

    /// NguyenLieuId cố định "Ứng (Nhã)" như backend (ThongKeService.UngNguyenLieuId) — KHÔNG lọc theo Ten.
    private static let ungNguyenLieuId = "7995B334-44D1-4768-89C7-280E6B0413AE"

    private var ungItems: [ChiTieuHangNgayDto] {
        chiTieuMonthItems.filter { $0.nguyenLieuId.caseInsensitiveCompare(Self.ungNguyenLieuId) == .orderedSame }
    }

    private var luongHienTai: Double { Double(luongHienTaiText.filter(\.isNumber)) ?? 0 }

    /// Gõ tới đâu format dấu chấm ngăn cách tới đó (kiểu "10.000.000").
    private static func formatThousands(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard let value = Int(digits) else { return "" }
        return HoaDonFormatting.moneyFormatter.string(from: NSNumber(value: value)) ?? digits
    }

    private func tinhKetQua(_ luong: LuongShipperDto) -> Double { luongHienTai - luong.chiUng }

    private var ketQua: Double? { luong.map(tinhKetQua) }

    fileprivate struct ThangKetQua: Identifiable {
        let thang: Int
        let nam: Int
        let ketQua: Double
        var id: String { "\(nam)-\(thang)" }
        var label: String { "T\(thang)" }
    }

    private var bieuDo6Thang: [ThangKetQua] {
        luong6ThangRaw.map { ThangKetQua(thang: $0.thang, nam: $0.nam, ketQua: tinhKetQua($0.luong)) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    Form {
                        Section { KetQuaCard(ketQua: ketQua) }
                            .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16))

                        Section {
                            HStack {
                                Text("Lương hiện tại")
                                TextField("10.000.000", text: $luongHienTaiText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .focused($luongFocused)
                                    .onChange(of: luongHienTaiText) { newValue in
                                        let formatted = Self.formatThousands(newValue)
                                        if formatted != newValue { luongHienTaiText = formatted }
                                    }
                                Text("đ").foregroundColor(.secondary)
                            }
                            Button { showUngDetail = true } label: {
                                HStack {
                                    Text("Đã ứng").foregroundColor(.primary)
                                    Spacer()
                                    MoneyText(value: luong?.chiUng ?? 0, color: .dangerColor)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                        } footer: {
                            Text("Còn nhận = Lương hiện tại − Đã ứng")
                        }

                        if !bieuDo6Thang.isEmpty {
                            Section("6 tháng gần đây") {
                                KetQua6ThangChart(items: bieuDo6Thang)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MonthStepperBar(date: $currentDate) { Task { await load() } }
            }
            .navigationBarTitleDisplayMode(.inline)
            .staffToolbar(isLoggedIn: $isLoggedIn)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Xong") { luongFocused = false }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showUngDetail) {
            ChiTieuThangDetailSheet(ten: "Ứng \(shipperTen)", items: ungItems)
        }
    }

    private func load() async {
        let cal = Calendar.current
        let thang = cal.component(.month, from: currentDate)
        let nam = cal.component(.year, from: currentDate)

        async let a = APIClient.shared.getLuongShipperThang(ten: shipperTen, thang: thang, nam: nam)
        async let b = APIClient.shared.getChiTieuByMonth(year: nam, month: thang)
        (luong, chiTieuMonthItems) = await (a, b)
        hasLoaded = true

        await load6Thang()
    }

    /// 6 tháng gần đây tính tới currentDate — gọi song song, giữ đúng thứ tự tăng dần cho biểu đồ.
    private func load6Thang() async {
        let cal = Calendar.current
        let thangNamList: [(thang: Int, nam: Int)] = (0..<6).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .month, value: -offset, to: currentDate) else { return nil }
            return (cal.component(.month, from: d), cal.component(.year, from: d))
        }
        let ten = shipperTen

        let results = await withTaskGroup(of: (Int, Int, Int, LuongShipperDto?).self) { group in
            for (index, tn) in thangNamList.enumerated() {
                group.addTask {
                    let luong = await APIClient.shared.getLuongShipperThang(ten: ten, thang: tn.thang, nam: tn.nam)
                    return (index, tn.thang, tn.nam, luong)
                }
            }
            var collected: [(Int, Int, Int, LuongShipperDto?)] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }
        }

        luong6ThangRaw = results.compactMap { _, thang, nam, luong in
            luong.map { (thang: thang, nam: nam, luong: $0) }
        }
    }
}

private struct KetQua6ThangChart: View {
    let items: [TinhLuongView.ThangKetQua]

    var body: some View {
        Chart(items) { item in
            BarMark(x: .value("Tháng", item.label), y: .value("Còn nhận", item.ketQua))
                .foregroundStyle(item.ketQua >= 0 ? Color.brandPrimary.gradient : Color.dangerColor.gradient)
                .cornerRadius(6)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(HoaDonFormatting.moneyShort(d)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
}

/// Số "Còn nhận" lớn ở đầu màn — xanh khi dương, đỏ khi âm.
private struct KetQuaCard: View {
    let ketQua: Double?

    private var color: Color {
        guard let ketQua else { return .secondary }
        return ketQua >= 0 ? .successColor : .dangerColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Còn nhận").font(.subheadline).foregroundColor(.secondary)
            if let ketQua {
                MoneyText(value: ketQua, font: .system(size: 36, weight: .bold, design: .rounded), color: color)
                Label(ketQua >= 0 ? "Chưa ứng quá lương" : "Đã ứng quá lương",
                      systemImage: ketQua >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(color)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
