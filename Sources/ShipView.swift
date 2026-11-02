import SwiftUI

/// Tab Ship — bản rút gọn của AppShipperAndroid (MainActivity + HoaDonAdapter), cùng API /api/shipper/*
/// (backend mặc định lọc đơn đã ESC cho shipper "Khánh"). Giữ: tổng Tiền mặt/CK/Trả nợ trong ngày, danh
/// sách đơn, 5 thao tác Tiền mặt/Chuyển khoản/Tí nữa CK/Ghi nợ/Trả nợ. Bỏ: dải chip theo nhóm, đọc TTS,
/// dịch vụ nền SignalR, popup — tải lại khi mở tab, kéo xuống hoặc quay lại app.
struct ShipView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date()
    @State private var hoaDons: [ShipperHoaDonDto] = []
    @State private var summary: ShipperSummaryDto?
    @State private var hasLoaded = false
    @State private var loadFailed = false
    @State private var loadGeneration = 0
    @State private var isBusy = false

    @State private var pending: PendingAction?
    @State private var traNoTarget: ShipperHoaDonDto?
    @State private var traNoInput = ""
    @State private var traNoConfirm: (hd: ShipperHoaDonDto, nghin: Int, duKien: Double)?
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
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
                            if loadFailed {
                                ThongKeLoadErrorBanner(text: "Chưa tải được danh sách đơn") { Task { await load() } }
                            }
                            summaryRow
                            if hoaDons.isEmpty && !loadFailed {
                                Text("Chưa có đơn ship nào")
                                    .font(.subheadline)
                                    .foregroundColor(.textMuted)
                                    .padding(.top, 40)
                            }
                            ForEach(hoaDons) { hd in
                                ShipCard(hd: hd, disabled: isBusy) { action in
                                    if action == .traNo { startTraNo(hd) } else { pending = PendingAction(hd: hd, kind: action) }
                                }
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationBarHidden(true)
        }
        .task { await load() }
        .onChange(of: scenePhase) { phase in
            if phase == .active && hasLoaded { Task { await load() } }
        }
        .confirmationDialog(
            pending.map { "Xác nhận \($0.kind.label.lowercased()) cho \($0.hd.tenHienThi)?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { p in
            Button(p.kind.label) { Task { await run(p.kind, hd: p.hd) } }
            Button("Huỷ", role: .cancel) {}
        }
        .alert(
            traNoTarget.map { "Khách \($0.tenHienThi) đang nợ \(HoaDonFormatting.money($0.tongNo))" } ?? "",
            isPresented: Binding(get: { traNoTarget != nil }, set: { if !$0 { traNoTarget = nil } }),
            presenting: traNoTarget
        ) { hd in
            TextField("Tổng tiền khách đưa (nghìn)", text: $traNoInput)
                .keyboardType(.numberPad)
            Button("Tiếp tục") { checkTraNo(hd) }
            Button("Huỷ", role: .cancel) {}
        } message: { _ in
            Text("Nhập TỔNG tiền khách đưa, tính bằng nghìn đồng.")
        }
        .alert(
            "Xác nhận trả nợ",
            isPresented: Binding(get: { traNoConfirm != nil }, set: { if !$0 { traNoConfirm = nil } }),
            presenting: traNoConfirm
        ) { c in
            Button("Xác nhận") { Task { await run(.traNo, hd: c.hd, traNoNghin: c.nghin) } }
            Button("Huỷ", role: .cancel) {}
        } message: { c in
            Text("Khách đưa \(HoaDonFormatting.money(Double(c.nghin) * 1000))\nDự kiến trả nợ: \(HoaDonFormatting.money(c.duKien))")
        }
        .alert(
            alertMessage ?? "",
            isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            SummaryPill(title: "Tiền mặt", value: summary?.tienMat, color: .successColor)
            SummaryPill(title: "Chuyển khoản", value: summary?.chuyenKhoan, color: .thongKeBlue)
            SummaryPill(title: "Trả nợ", value: summary.map { $0.traNoTrongNgay + $0.traNoQuaNgay }, color: .thongKePurple)
        }
    }

    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let ymd = DateNavFormat.queryDate.string(from: currentDate)
        async let list = APIClient.shared.getShipperList(dateYmd: ymd)
        async let sum = APIClient.shared.getShipperSummary(dateYmd: ymd)
        let r = await (list, sum)
        guard generation == loadGeneration else { return }
        if let l = r.0 { hoaDons = l } else if !hasLoaded { hoaDons = [] }
        summary = r.1 ?? summary
        loadFailed = r.0 == nil
        hasLoaded = true
    }

    private func startTraNo(_ hd: ShipperHoaDonDto) {
        if hd.tongNo <= 0 { alertMessage = "Khách \(hd.tenHienThi) không còn nợ."; return }
        if hd.conLai > 0 {
            alertMessage = "Đơn này còn \(HoaDonFormatting.money(hd.conLai)).\nHãy bấm Tiền mặt trước rồi mới thu nợ."
            return
        }
        traNoInput = ""
        traNoTarget = hd
    }

    private func checkTraNo(_ hd: ShipperHoaDonDto) {
        guard let nghin = Int(traNoInput.filter(\.isNumber)), nghin > 0 else {
            alertMessage = "Số tiền không hợp lệ."
            return
        }
        let khachDua = Double(nghin) * 1000
        guard khachDua > hd.thanhTien else {
            alertMessage = "Tổng tiền khách đưa phải lớn hơn tiền đơn hôm nay \(HoaDonFormatting.money(hd.thanhTien))"
            return
        }
        traNoConfirm = (hd, nghin, min(khachDua - hd.thanhTien, hd.tongNo))
    }

    private func run(_ kind: ShipAction, hd: ShipperHoaDonDto, traNoNghin: Int = 0) async {
        guard !isBusy else { return }
        isBusy = true
        let result = await APIClient.shared.shipperAction(kind, id: hd.id, traNoNghin: traNoNghin)
        isBusy = false
        if result.success {
            await load()
        } else {
            alertMessage = result.message ?? "Cập nhật thất bại"
        }
    }
}

private struct PendingAction {
    let hd: ShipperHoaDonDto
    let kind: ShipAction
}

enum ShipAction {
    case tienMat, chuyenKhoan, tiNua, ghiNo, traNo

    var label: String {
        switch self {
        case .tienMat: return "Tiền mặt"
        case .chuyenKhoan: return "Chuyển khoản"
        case .tiNua: return "Tí nữa CK"
        case .ghiNo: return "Ghi nợ"
        case .traNo: return "Trả nợ"
        }
    }

    var color: Color {
        switch self {
        case .tienMat: return .successColor
        case .chuyenKhoan: return .thongKeBlue
        case .tiNua: return .thongKeOrange
        case .ghiNo: return .dangerColor
        case .traNo: return .thongKePurple
        }
    }

    /// Endpoint /api/shipper/* — khớp ApiClient.kt bên AppShipperAndroid.
    var path: String {
        switch self {
        case .tienMat: return "shipperf1"
        case .chuyenKhoan: return "shipperf4"
        case .tiNua: return "shipper55"
        case .ghiNo: return "shipper12"
        case .traNo: return "shipper99"
        }
    }
}

/// Trạng thái suy từ GhiChuShipper (backend ghi "Tiền mặt…", "Chuyển khoản…", "Ghi nợ…", "Tí nữa…").
extension ShipperHoaDonDto {
    var status: ShipAction? {
        let note = (ghiChuShipper ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if note.hasPrefix("tiền mặt") { return .tienMat }
        if note.hasPrefix("chuyển khoản") { return .chuyenKhoan }
        if note.hasPrefix("ghi nợ") { return .ghiNo }
        if note.hasPrefix("tí nữa") { return .tiNua }
        return nil
    }

    /// Chưa chọn: đủ 4 nút. Đã Tiền mặt/Tí nữa CK mà khách còn nợ: chỉ còn Trả nợ. CK/Ghi nợ: khoá hết.
    /// Trả nợ chỉ hiện khi đơn đã thu đủ (Android hiện sẵn rồi báo "bấm Tiền mặt trước" — bỏ bước thừa).
    var actions: [ShipAction] {
        let traNo: [ShipAction] = tongNo > 0 && conLai <= 0 ? [.traNo] : []
        switch status {
        case nil: return [.tienMat, .chuyenKhoan, .tiNua, .ghiNo] + traNo
        case .tienMat?, .tiNua?: return traNo
        default: return []
        }
    }

    var gioShip: String? {
        guard let s = ngayShip, let r = s.range(of: #"T\d{2}:\d{2}"#, options: .regularExpression) else { return nil }
        return String(s[r].dropFirst())
    }
}

private struct SummaryPill: View {
    let title: String
    let value: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundColor(.textMuted)
            Text(value.map(HoaDonFormatting.money) ?? "—")
                .font(.subheadline.bold())
                .foregroundColor(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ShipCard: View {
    let hd: ShipperHoaDonDto
    let disabled: Bool
    let onAction: (ShipAction) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(hd.tenHienThi).font(.headline)
                if let gio = hd.gioShip {
                    Text(gio).font(.caption.weight(.semibold)).foregroundColor(.textMuted)
                }
                Spacer()
                if let s = hd.status {
                    Text(s.label)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(s.color))
                } else {
                    Text(HoaDonFormatting.money(hd.conLai))
                        .font(.headline)
                        .foregroundColor(.brandPrimary)
                        .monospacedDigit()
                }
            }
            if let dc = hd.diaChiText, !dc.isEmpty {
                Text(dc).font(.subheadline).foregroundColor(.secondary)
            }
            if let sdt = hd.soDienThoaiText, !sdt.isEmpty,
               let url = URL(string: "tel:\(sdt.filter { $0.isNumber || $0 == "+" })") {
                Link(destination: url) {
                    Label(sdt, systemImage: "phone.fill").font(.subheadline.weight(.medium))
                }
            }
            if hd.tongNo > 0 {
                Text("Tổng nợ: \(HoaDonFormatting.money(hd.tongNo))")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.dangerColor)
            }
            let actions = hd.actions
            if !actions.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(actions, id: \.self) { a in
                        Button { onAction(a) } label: {
                            Text(a.label)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(.white)
                                .background(a.color)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                        .opacity(disabled ? 0.5 : 1)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((hd.status?.color ?? .brandPrimary).opacity(hd.status == nil ? 0.05 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}
