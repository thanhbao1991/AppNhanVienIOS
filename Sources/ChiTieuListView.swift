import SwiftUI

/// Chi tiêu hằng ngày — GET/POST/PUT/DELETE /api/ChiTieuHangNgay. List theo ngày, chia 2 nhóm "Chi
/// ngày"/"Bill tháng", ô tìm kiếm chuẩn iOS. Chạm 1 dòng để sửa (form có nút Xoá), vuốt trái để xoá —
/// mọi lần xoá đều qua bước xác nhận.
struct ChiTieuListView: View {
    @Binding var isLoggedIn: Bool
    @State private var currentDate = Date()
    @State private var items: [ChiTieuHangNgayDto] = []
    @State private var hasLoaded = false
    @State private var searchText = ""
    @State private var editingItem: ChiTieuHangNgayDto?
    @State private var deletingItem: ChiTieuHangNgayDto?
    @State private var showAdd = false
    @State private var errorMessage: String?

    private var filtered: [ChiTieuHangNgayDto] {
        items.filter { anyMatchesSearch(searchText, $0.ten, $0.ghiChu) }
    }
    private var chiNgay: [ChiTieuHangNgayDto] { filtered.filter { !$0.billThang } }
    private var billThang: [ChiTieuHangNgayDto] { filtered.filter(\.billThang) }
    private func sum(_ list: [ChiTieuHangNgayDto]) -> Double { list.reduce(0) { $0 + $1.thanhTien } }

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded {
                    fullScreenLoading()
                } else {
                    List {
                        Section { totalHeader }
                            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

                        if filtered.isEmpty {
                            Section {
                                EmptyStateView(
                                    symbol: searchText.isEmpty ? "cart" : "magnifyingglass",
                                    title: searchText.isEmpty ? "Chưa có chi tiêu" : "Không tìm thấy",
                                    message: searchText.isEmpty ? "Bấm + để thêm khoản chi trong ngày." : nil
                                )
                            }
                        }
                        if !chiNgay.isEmpty {
                            section("Chi ngày", chiNgay)
                        }
                        if !billThang.isEmpty {
                            section("Bill tháng", billThang)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .nenApp()
                    .refreshable { await load() }
                }
            }
            // Ngày nằm giữa thanh trên (giữa tài khoản và chuông) — tiết kiệm chỗ (chủ quán 2026-11-08).
            .toolbar { ToolbarItem(placement: .principal) { DateStepperBar(date: $currentDate) { Task { await load() } } } }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Tìm nguyên liệu, ghi chú")
            .navigationBarTitleDisplayMode(.inline)
            .staffToolbar(isLoggedIn: $isLoggedIn) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22))
                }
                .accessibilityLabel("Thêm chi tiêu")
            }
        }
        .task { await load() }
        .sheet(item: $editingItem) { item in
            EditExpenseSheet(item: item) { Task { await load() } }
        }
        .sheet(isPresented: $showAdd) {
            AddExpenseSheet(date: currentDate) { Task { await load() } }
        }
        .confirmationDialog(
            "Xoá \"\(deletingItem?.ten ?? "")\"?",
            isPresented: Binding(get: { deletingItem != nil }, set: { if !$0 { deletingItem = nil } }),
            titleVisibility: .visible,
            presenting: deletingItem
        ) { item in
            Button("Xoá chi tiêu", role: .destructive) { Task { await delete(item) } }
            Button("Huỷ", role: .cancel) {}
        } message: { _ in
            Text("Không thể hoàn tác.")
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var totalHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tổng chi").font(.subheadline).foregroundColor(.secondary)
                MoneyText(value: sum(filtered), font: .system(size: 30, weight: .bold, design: .rounded))
            }
            HStack(spacing: 16) {
                legend("Chi ngày", sum(chiNgay), .successColor)
                legend("Bill tháng", sum(billThang), .brandPrimary)
            }
        }
    }

    private func legend(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.footnote).foregroundColor(.secondary)
            MoneyText(value: value, font: .footnote.weight(.semibold))
        }
    }

    private func section(_ title: String, _ list: [ChiTieuHangNgayDto]) -> some View {
        Section {
            ForEach(list) { item in
                Button { editingItem = item } label: { ChiTieuRow(item: item) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deletingItem = item } label: {
                            Label("Xoá", systemImage: "trash")
                        }
                    }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(HoaDonFormatting.money(sum(list))).monospacedDigit()
            }
        }
    }

    private func load() async {
        items = await APIClient.shared.getChiTieuByDay(DateNavFormat.queryDate.string(from: currentDate))
        hasLoaded = true
    }

    private func delete(_ item: ChiTieuHangNgayDto) async {
        let result = await APIClient.shared.deleteChiTieu(id: item.id)
        if result.success {
            items.removeAll { $0.id == item.id }
        } else {
            errorMessage = result.message ?? "Không xoá được."
        }
    }
}

private struct ChiTieuRow: View {
    let item: ChiTieuHangNgayDto

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.ten).font(.body).foregroundColor(.primary)
                Text(subtitle).font(.footnote).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            MoneyText(value: item.thanhTien, font: .body.weight(.semibold))
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var s = "\(item.soLuong.formatted()) × \(HoaDonFormatting.money(item.donGia))"
        if let ghiChu = item.ghiChu, !ghiChu.isEmpty { s += " · \(ghiChu)" }
        return s
    }
}

/// Số lượng (Stepper) + Thành tiền (nhập) + Đơn giá (tự tính = Thành tiền / Số lượng). Nhân viên hay gộp
/// nhiều lần mua thành 1 lần trả nên biết chắc tổng tiền hơn đơn giá. Dùng chung cho form Thêm và Sửa.
private struct QuantityPriceFields: View {
    @Binding var soLuong: Double
    @Binding var thanhTien: Double

    private var donGia: Double { soLuong > 0 ? thanhTien / soLuong : 0 }

    var body: some View {
        Stepper(value: $soLuong, in: 1...99_999, step: 1) {
            HStack {
                Text("Số lượng")
                Spacer()
                Text(soLuong.formatted()).monospacedDigit().foregroundColor(.secondary)
            }
        }
        HStack {
            Text("Thành tiền")
            TextField("0", value: $thanhTien, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold))
            Text("đ").foregroundColor(.secondary)
        }
        LabeledContent("Đơn giá") {
            MoneyText(value: donGia, color: .secondary)
        }
    }
}

/// Sửa 1 dòng chi tiêu — số lượng/thành tiền/ghi chú/loại đều sửa được; tên nguyên liệu giữ cố định
/// (đổi nguyên liệu thực chất là 1 khoản chi khác). Có nút Xoá ở cuối form.
private struct EditExpenseSheet: View {
    let item: ChiTieuHangNgayDto
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var soLuong: Double
    @State private var thanhTien: Double
    @State private var ghiChu: String
    @State private var billThang: Bool
    @State private var saving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var warningAlertText: String?

    private var donGia: Double { soLuong > 0 ? thanhTien / soLuong : 0 }

    init(item: ChiTieuHangNgayDto, onChanged: @escaping () -> Void) {
        self.item = item
        self.onChanged = onChanged
        _soLuong = State(initialValue: item.soLuong)
        _thanhTien = State(initialValue: item.thanhTien)
        _ghiChu = State(initialValue: item.ghiChu ?? "")
        _billThang = State(initialValue: item.billThang)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    QuantityPriceFields(soLuong: $soLuong, thanhTien: $thanhTien)
                } header: {
                    Text(item.ten)
                }

                Section {
                    TextField("Ghi chú", text: $ghiChu)
                    Toggle("Bill tháng", isOn: $billThang)
                } footer: {
                    if let tk = item.tenTaiKhoan, !tk.isEmpty { Text("Người thêm: \(tk)") }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.dangerColor) }
                }

                Section {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Text("Xoá chi tiêu").frame(maxWidth: .infinity)
                    }
                }
            }
            .nenApp()
            .navigationTitle("Sửa chi tiêu")
            .navigationBarTitleDisplayMode(.inline)
            .thanhTrenThuongHieu()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() }.foregroundColor(.white) }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView().tint(.white) } else {
                        Button("Lưu") { Task { await save() } }
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(thanhTien <= 0 ? 0.45 : 1))
                            .disabled(thanhTien <= 0)
                    }
                }
            }
            .interactiveDismissDisabled(saving)
        }
        .confirmationDialog("Xoá \"\(item.ten)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Xoá chi tiêu", role: .destructive) { Task { await delete() } }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Không thể hoàn tác.")
        }
        // Backend đã lưu nhưng đơn giá mới lệch lớn so với lần mua gần nhất — chỉ cảnh báo, không chặn.
        .alert("Giá bất thường", isPresented: Binding(
            get: { warningAlertText != nil },
            set: { if !$0 { warningAlertText = nil } }
        )) {
            Button("Đã hiểu") { onChanged(); dismiss() }
        } message: {
            Text(warningAlertText ?? "")
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        let ngayIso = (item.ngay ?? item.ngayGio) ?? ""
        let ngayGioIso = item.ngayGio ?? ngayIso
        let body = ChiTieuHangNgayCreateRequest(
            ten: item.ten, soLuong: soLuong, donGia: donGia, thanhTien: thanhTien,
            ghiChu: ghiChu.isEmpty ? nil : ghiChu, ngay: ngayIso, ngayGio: ngayGioIso,
            nguyenLieuId: item.nguyenLieuId, billThang: billThang
        )
        let result = await APIClient.shared.updateChiTieu(id: item.id, body)
        saving = false
        if result.success {
            if let warning = result.warnings.first {
                warningAlertText = warning
            } else {
                onChanged()
                dismiss()
            }
        } else {
            errorMessage = result.message ?? "Không lưu được."
        }
    }

    private func delete() async {
        saving = true
        errorMessage = nil
        let result = await APIClient.shared.deleteChiTieu(id: item.id)
        saving = false
        if result.success {
            onChanged()
            dismiss()
        } else {
            errorMessage = result.message ?? "Không xoá được."
        }
    }
}

struct AddExpenseSheet: View {
    let date: Date
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nguyenLieuList: [NguyenLieuDto] = []
    @State private var searchText = ""
    @State private var selected: NguyenLieuDto?
    @State private var soLuong: Double = 1
    @State private var thanhTien: Double = 0
    @State private var ghiChu = ""
    @State private var billThang = false
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var addingNguyenLieu = false
    @State private var warningAlertText: String?
    @FocusState private var searchFocused: Bool

    /// Rỗng khi chưa gõ gì — danh sách nguyên liệu quá dài để liệt kê hết, phải gõ tìm mới hiện.
    private var filteredList: [NguyenLieuDto] {
        guard !searchText.isEmpty else { return [] }
        return nguyenLieuList.filter { !$0.ngungSuDung && $0.ten.matchesSearch(searchText) }
    }

    private var donGia: Double { soLuong > 0 ? thanhTien / soLuong : 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nguyên liệu") {
                    if let selected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.successColor)
                            Text(selected.ten).fontWeight(.semibold)
                            Spacer()
                            Button("Đổi") { self.selected = nil; searchFocused = true }
                                .buttonStyle(.borderless)
                        }
                    } else {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Tìm nguyên liệu", text: $searchText)
                                .focused($searchFocused)
                                .autocorrectionDisabled()
                        }
                        ForEach(filteredList.prefix(30)) { nl in
                            Button {
                                selected = nl
                                searchText = ""
                                // Gợi ý Thành tiền = Số lượng × giá nhập gần nhất — chỉ là điểm khởi đầu.
                                if nl.giaNhap > 0 { thanhTien = soLuong * nl.giaNhap }
                            } label: {
                                HStack {
                                    Text(nl.ten).foregroundColor(.primary)
                                    Spacer()
                                    if nl.giaNhap > 0 {
                                        Text(HoaDonFormatting.money(nl.giaNhap)).font(.footnote).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        // Gõ tên không khớp nguyên liệu nào — cho thêm mới ngay tại đây.
                        if !searchText.isEmpty && filteredList.isEmpty {
                            Button {
                                Task { await addNewNguyenLieu() }
                            } label: {
                                if addingNguyenLieu {
                                    ProgressView()
                                } else {
                                    Label("Thêm nguyên liệu \"\(searchText)\"", systemImage: "plus.circle.fill")
                                }
                            }
                            .disabled(addingNguyenLieu)
                        }
                    }
                }

                Section("Số lượng & thành tiền") {
                    QuantityPriceFields(soLuong: $soLuong, thanhTien: $thanhTien)
                }

                Section {
                    TextField("Ghi chú", text: $ghiChu)
                    Toggle("Bill tháng", isOn: $billThang)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.dangerColor) }
                }
            }
            .nenApp()
            .navigationTitle("Thêm chi tiêu")
            .navigationBarTitleDisplayMode(.inline)
            .thanhTrenThuongHieu()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() }.foregroundColor(.white) }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView().tint(.white) } else {
                        Button("Lưu") { Task { await save() } }
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(selected == nil || thanhTien <= 0 ? 0.45 : 1))
                            .disabled(selected == nil || thanhTien <= 0)
                    }
                }
            }
            .interactiveDismissDisabled(saving)
        }
        .task {
            nguyenLieuList = await APIClient.shared.getNguyenLieu()
            searchFocused = true
        }
        // Backend đã lưu nhưng giá lệch lớn so với lần mua gần nhất — chỉ cảnh báo, không chặn.
        .alert("Giá bất thường", isPresented: Binding(
            get: { warningAlertText != nil },
            set: { if !$0 { warningAlertText = nil } }
        )) {
            Button("Đã hiểu") { onSaved(); dismiss() }
        } message: {
            Text(warningAlertText ?? "")
        }
    }

    private func addNewNguyenLieu() async {
        let ten = searchText.trimmingCharacters(in: .whitespaces)
        guard !ten.isEmpty else { return }
        addingNguyenLieu = true
        errorMessage = nil
        let result = await APIClient.shared.createNguyenLieu(ten: ten)
        addingNguyenLieu = false
        if result.success, let nl = result.nguyenLieu {
            nguyenLieuList.append(nl)
            selected = nl
            searchText = ""
        } else {
            errorMessage = result.message ?? "Không thêm được nguyên liệu."
        }
    }

    private func save() async {
        guard let selected else { return }
        saving = true
        errorMessage = nil
        let dateIso = DateNavFormat.queryDate.string(from: date) + "T00:00:00"
        let body = ChiTieuHangNgayCreateRequest(
            ten: selected.ten, soLuong: soLuong, donGia: donGia, thanhTien: thanhTien,
            ghiChu: ghiChu.isEmpty ? nil : ghiChu,
            // NgayGio do server quyết định (VietnamTime.Now) — giá trị gửi đây không được server dùng.
            ngay: dateIso, ngayGio: dateIso, nguyenLieuId: selected.id, billThang: billThang
        )
        let result = await APIClient.shared.createChiTieu(body)
        saving = false
        if result.success {
            if let warning = result.warnings.first {
                warningAlertText = warning
            } else {
                onSaved()
                dismiss()
            }
        } else {
            errorMessage = result.message ?? "Không thêm được chi tiêu."
        }
    }
}
