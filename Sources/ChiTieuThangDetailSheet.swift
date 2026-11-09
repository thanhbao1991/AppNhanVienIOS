import SwiftUI

/// Danh sách các lần chi của 1 nguyên liệu trong tháng (vd "Ứng Nhã") — mới trước.
struct ChiTieuThangDetailSheet: View {
    let ten: String
    let items: [ChiTieuHangNgayDto]

    @Environment(\.dismiss) private var dismiss

    private var sorted: [ChiTieuHangNgayDto] {
        items.sorted { ($0.ngay ?? $0.ngayGio ?? "") > ($1.ngay ?? $1.ngayGio ?? "") }
    }

    private var total: Double { items.reduce(0) { $0 + $1.thanhTien } }

    private func dayLabel(_ item: ChiTieuHangNgayDto) -> String {
        guard let date = HoaDonFormatting.parseIso(item.ngay ?? item.ngayGio) else { return "?" }
        return DateNavFormat.weekdayTitle.string(from: date).capitalizedFirst
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AmountRow(label: "Tổng cộng", value: total, bold: true)
                }
                Section {
                    if sorted.isEmpty {
                        EmptyStateView(symbol: "tray", title: "Chưa có khoản nào")
                    }
                    ForEach(sorted) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dayLabel(item))
                                if let ghiChu = item.ghiChu, !ghiChu.isEmpty {
                                    Text(ghiChu).font(.footnote).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            MoneyText(value: item.thanhTien, font: .body.weight(.semibold))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .nenApp()
            .navigationTitle(ten)
            .navigationBarTitleDisplayMode(.inline)
            .thanhTrenThuongHieu()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() }.foregroundColor(.white) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
