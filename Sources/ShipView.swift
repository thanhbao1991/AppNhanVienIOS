import SwiftUI

/// Tab Ship — bản rút gọn của AppShipperAndroid (MainActivity + HoaDonAdapter), cùng API /api/shipper/*
/// nhưng lọc đơn ESC cho shipper "Nhã" (Android là Khánh) và CHỈ đơn phân loại Ship (bỏ AppDatHang).
/// Giữ: tổng Tiền mặt/CK/Trả nợ trong ngày, danh sách đơn, 5 thao tác Tiền mặt/Chuyển khoản/Tí nữa CK/
/// Ghi nợ/Trả nợ. Bỏ: dải chip theo nhóm, đọc TTS, dịch vụ nền SignalR, popup — tải lại khi mở tab,
/// kéo xuống hoặc quay lại app.
struct ShipView: View {
    static let shipper = "Nhã"

    @Binding var isLoggedIn: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date()
    @State private var hoaDons: [ShipperHoaDonDto] = []
    @State private var hasLoaded = false
    @State private var loadFailed = false
    @State private var loadGeneration = 0
    @State private var busyId: String?

    @State private var pending: PendingAction?
    @State private var traNoTarget: ShipperHoaDonDto?
    @State private var traNoInput = ""
    @State private var traNoConfirm: TraNoConfirm?
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    List {
                        if loadFailed {
                            Section { LoadErrorRow(text: "Chưa tải được danh sách đơn") { Task { await load() } } }
                        }
                        Section { summaryRow }
                        if hoaDons.isEmpty && !loadFailed {
                            Section {
                                EmptyStateView(symbol: "bicycle", title: "Chưa có đơn ship",
                                               message: "Đơn Ship giao cho \(Self.shipper) trong ngày sẽ hiện ở đây.")
                            }
                        }
                        ForEach(Array(hoaDons.enumerated()), id: \.element.id) { index, hd in
                            Section {
                                ShipOrderRows(hd: hd, busy: busyId == hd.id, disabled: busyId != nil) { action in
                                    if action == .traNo { startTraNo(hd) } else { pending = PendingAction(hd: hd, kind: action) }
                                }
                            } header: {
                                if index == 0 { Text("\(hoaDons.count) đơn") }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                DateStepperBar(date: $currentDate) { Task { await load() } }
            }
            .navigationBarTitleDisplayMode(.inline)
            .staffToolbar(isLoggedIn: $isLoggedIn)
        }
        .task { await load() }
        .onChange(of: scenePhase) { phase in
            if phase == .active && hasLoaded { Task { await load() } }
        }
        .confirmationDialog(
            pending.map { "\($0.kind.label) — \($0.hd.tenHienThi)" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { p in
            Button("Xác nhận \(p.kind.label.lowercased())", role: p.kind == .ghiNo ? ButtonRole.destructive : nil) {
                Task { await run(p.kind, hd: p.hd) }
            }
            Button("Huỷ", role: .cancel) {}
        } message: { p in
            Text(p.hd.conLai > 0 ? "Đơn còn \(HoaDonFormatting.money(p.hd.conLai))" : "")
        }
        .alert(
            traNoTarget.map { "\($0.tenHienThi) đang nợ \(HoaDonFormatting.money($0.tongNo))" } ?? "",
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

    /// Tự cộng từ danh sách đơn của Nhã — KHÔNG dùng /api/shipper/summary vì API đó gộp mọi khoản thu
    /// ghi chú "Shipper" (lẫn cả của Khánh qua AppShipperAndroid).
    private var summaryRow: some View {
        let tienMat = hoaDons.filter { $0.status == .tienMat }.reduce(0) { $0 + $1.thanhTien }
        let ck = hoaDons.filter { $0.status == .chuyenKhoan }.reduce(0) { $0 + $1.thanhTien }
        let traNo = hoaDons.reduce(0) { $0 + $1.traNoDaThu }
        return HStack(spacing: 0) {
            summaryCell("Tiền mặt", tienMat, .successColor)
            Divider().frame(height: 32)
            summaryCell("Chuyển khoản", ck, .thongKeBlue)
            Divider().frame(height: 32)
            summaryCell("Trả nợ", traNo, .thongKePurple)
        }
        .padding(.vertical, 4)
    }

    private func summaryCell(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption).foregroundColor(.secondary)
            MoneyText(value: value, font: .subheadline.weight(.semibold), color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let ymd = DateNavFormat.queryDate.string(from: currentDate)
        let list = await APIClient.shared.getShipperList(dateYmd: ymd, shipper: Self.shipper)
        guard generation == loadGeneration else { return }
        // Chỉ đơn Ship — AppDatHang (đơn app khách) không hiện ở tab này.
        if let list { hoaDons = list.filter { ($0.phanLoai ?? "Ship") == "Ship" } } else if !hasLoaded { hoaDons = [] }
        loadFailed = list == nil
        hasLoaded = true
    }

    private func startTraNo(_ hd: ShipperHoaDonDto) {
        traNoInput = ""
        traNoTarget = hd
    }

    private func checkTraNo(_ hd: ShipperHoaDonDto) {
        guard let nghin = Int(traNoInput.filter(\.isNumber)), nghin > 0 else {
            alertMessage = "Số tiền không hợp lệ."
            return
        }
        let khachDua = Double(nghin) * 1000
        guard khachDua > hd.shipperDaThu else {
            alertMessage = "Tổng tiền khách đưa phải lớn hơn tiền đơn hôm nay \(HoaDonFormatting.money(hd.shipperDaThu))"
            return
        }
        traNoConfirm = TraNoConfirm(hd: hd, nghin: nghin, duKien: min(khachDua - hd.shipperDaThu, hd.tongNo))
    }

    private func run(_ kind: ShipAction, hd: ShipperHoaDonDto, traNoNghin: Int = 0) async {
        guard busyId == nil else { return }
        busyId = hd.id
        let result = await APIClient.shared.shipperAction(kind, id: hd.id, traNoNghin: traNoNghin)
        if result.success {
            await load()
        } else {
            alertMessage = result.message ?? "Cập nhật thất bại"
        }
        busyId = nil
    }
}

private struct PendingAction {
    let hd: ShipperHoaDonDto
    let kind: ShipAction
}

private struct TraNoConfirm {
    let hd: ShipperHoaDonDto
    let nghin: Int
    let duKien: Double
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

    var symbol: String {
        switch self {
        case .tienMat: return "banknote"
        case .chuyenKhoan: return "qrcode"
        case .tiNua: return "clock"
        case .ghiNo: return "book.closed"
        case .traNo: return "arrow.uturn.left.circle"
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
        // Ghi nợ ở quầy (F12 Desktop) chỉ set NgayNo, không ghi GhiChuShipper.
        if let ngayNo, !ngayNo.isEmpty { return .ghiNo }
        let note = (ghiChuShipper ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if note.hasPrefix("tiền mặt") { return .tienMat }
        if note.hasPrefix("chuyển khoản") { return .chuyenKhoan }
        if note.hasPrefix("ghi nợ") { return .ghiNo }
        if note.hasPrefix("tí nữa") { return .tiNua }
        return nil
    }

    /// Đơn chưa shipper xử lý nhưng đã thu đủ ở chỗ khác (quầy / chuyển khoản tự động).
    var daThanhToanNoiKhac: Bool { status == nil && conLai <= 0 }

    /// Chỉ hiện nút mà backend (ShipperActionService) sẽ CHẤP NHẬN — AppShipperAndroid hiện đủ 4 nút cho
    /// mọi đơn chưa chọn kể cả đơn đã thu đủ (bấm vào mới bị server báo lỗi), iOS chặn trước:
    /// - Tiền mặt / CK / Tí nữa CK: chưa shipper xử lý (GhiChuShipper trống) VÀ còn tiền thu.
    /// - Ghi nợ: như trên + đơn có gắn khách.
    /// - Trả nợ: khách có nợ cũ, đơn đã thu đủ, và đơn không phải CK/Ghi nợ.
    var actions: [ShipAction] {
        var list: [ShipAction] = []
        if status == nil && conLai > 0 {
            list = [.tienMat, .chuyenKhoan, .tiNua]
            if khachHangId != nil { list.append(.ghiNo) }
        }
        if khachHangId != nil && tongNo > 0 && conLai <= 0 && status != .chuyenKhoan && status != .ghiNo {
            list.append(.traNo)
        }
        return list
    }

    /// Tiền đơn shipper đã tự thu — server trừ khoản này khỏi tiền khách đưa khi tính Trả nợ (chỉ đếm
    /// thanh toán ghi chú "Shipper"). Đơn trả ở quầy thì shipper chưa thu gì → toàn bộ tiền đưa là trả nợ.
    var shipperDaThu: Double { status == .tienMat ? thanhTien : 0 }

    /// Backend nối "| Trả nợ: 150.000 ₫" vào GhiChuShipper sau mỗi lần trả nợ (ShipperActionService.TraNoAsync)
    /// — cộng các số đó lại. Dấu phân cách nghìn tuỳ culture server (. hoặc ,) nên chỉ lấy chữ số.
    var traNoDaThu: Double {
        guard let note = ghiChuShipper else { return 0 }
        return note.components(separatedBy: "Trả nợ:").dropFirst().reduce(0) { sum, part in
            let so = part.prefix { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }.filter(\.isNumber)
            return sum + (Double(so) ?? 0)
        }
    }

    var gioShip: String? {
        guard let s = ngayShip, let r = s.range(of: #"T\d{2}:\d{2}"#, options: .regularExpression) else { return nil }
        return String(s[r].dropFirst())
    }
}

/// Các dòng của 1 đơn trong Section: thông tin khách → liên hệ/nợ → nút thao tác.
private struct ShipOrderRows: View {
    let hd: ShipperHoaDonDto
    let busy: Bool
    let disabled: Bool
    let onAction: (ShipAction) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hd.tenHienThi).font(.headline)
                if let dc = hd.diaChiText, !dc.isEmpty {
                    Text(dc).font(.subheadline).foregroundColor(.secondary)
                }
                if let gio = hd.gioShip {
                    Label("Giao lúc \(gio)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                // Còn tiền phải thu → số còn lại (đậm); đã xong → tiền đơn (mờ).
                let conThu = hd.status == nil && hd.conLai > 0
                MoneyText(value: conThu ? hd.conLai : hd.thanhTien, font: .headline,
                          color: conThu ? .primary : .secondary)
                if let s = hd.status {
                    badge(s.label, s.symbol, s.color)
                } else if hd.daThanhToanNoiKhac {
                    badge("Đã thanh toán", "checkmark.circle.fill", .secondary)
                }
            }
        }
        .padding(.vertical, 4)

        if let sdt = hd.soDienThoaiText, !sdt.isEmpty,
           let url = URL(string: "tel:\(sdt.filter { $0.isNumber || $0 == "+" })") {
            Link(destination: url) {
                HStack {
                    Label(sdt, systemImage: "phone.fill")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(.secondary.opacity(0.5))
                }
            }
        }

        if hd.tongNo > 0 {
            HStack {
                Label("Khách đang nợ", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.dangerColor)
                Spacer()
                MoneyText(value: hd.tongNo, font: .body.weight(.semibold), color: .dangerColor)
            }
            .font(.subheadline)
        }

        let actions = hd.actions
        if !actions.isEmpty {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(actions, id: \.self) { a in
                    Button { onAction(a) } label: {
                        Label(a.label, systemImage: a.symbol)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(a.color)
                    .disabled(disabled)
                }
            }
            .padding(.vertical, 6)
            .overlay { if busy { ProgressView() } }
        }
    }

    private func badge(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
