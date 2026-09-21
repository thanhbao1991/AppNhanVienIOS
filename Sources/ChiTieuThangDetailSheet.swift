import SwiftUI

/// Không private — ThongKeView tái dùng, truyền items đã lọc theo ngày thay vì cả tháng.
struct ChiTieuThangDetailSheet: View {
    let ten: String
    let items: [ChiTieuHangNgayDto]

    @Environment(\.dismiss) private var dismiss

    /// Mới trước — khớp thứ tự dùng chung mọi list khác trong app (HoaDonListView, CongNoListView...).
    private var sorted: [ChiTieuHangNgayDto] {
        items.sorted { ($0.ngay ?? $0.ngayGio ?? "") > ($1.ngay ?? $1.ngayGio ?? "") }
    }

    private var total: Double { items.reduce(0) { $0 + $1.thanhTien } }

    private func dayLabel(_ item: ChiTieuHangNgayDto) -> String {
        guard let date = HoaDonFormatting.parseIso(item.ngay ?? item.ngayGio) else { return "?" }
        return DateNavFormat.dayTitle.string(from: date)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Tổng cộng").foregroundColor(.textMuted)
                        Spacer()
                        Text(HoaDonFormatting.money(total)).font(.headline).monospacedDigit()
                    }
                }
                ForEach(sorted) { item in
                    HStack {
                        Text(dayLabel(item)).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(HoaDonFormatting.money(item.thanhTien))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(ten)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.brandPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
