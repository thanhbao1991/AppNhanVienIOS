import SwiftUI

/// Màn "Ảnh menu" — nhân viên đổi/thêm ảnh món cho AppDatHangIOS (app khách đặt hàng). Món chia theo
/// nhóm, ô tìm kiếm chuẩn iOS, mỗi dòng có nút máy ảnh mở menu Chọn ảnh / Chụp ảnh.
struct SanPhamHinhAnhListView: View {
    @Binding var isLoggedIn: Bool
    @State private var sanPhams: [SanPhamDto] = []
    @State private var loading = true
    @State private var query = ""
    @State private var uploadingId: String?
    @State private var errorMessage: String?

    private var groups: [(nhom: String, items: [SanPhamDto])] {
        let filtered = sanPhams.filter { $0.ten.matchesSearch(query) }
        let dict = Dictionary(grouping: filtered) { $0.tenNhomSanPham?.isEmpty == false ? $0.tenNhomSanPham! : "Khác" }
        return dict
            .map { (nhom: $0.key, items: $0.value.sorted { ($0.thuTu, $0.ten) < ($1.thuTu, $1.ten) }) }
            .sorted { ($0.items.first?.thuTu ?? 0, $0.nhom) < ($1.items.first?.thuTu ?? 0, $1.nhom) }
    }

    private var soChuaCoAnh: Int { sanPhams.filter { $0.hinhAnh == nil }.count }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    List {
                        if query.isEmpty && soChuaCoAnh > 0 {
                            Section {
                                Label("\(soChuaCoAnh) món chưa có ảnh", systemImage: "photo.badge.plus")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if groups.isEmpty {
                            Section { EmptyStateView(symbol: "magnifyingglass", title: "Không tìm thấy món") }
                        }
                        ForEach(groups, id: \.nhom) { group in
                            Section(group.nhom) {
                                ForEach(group.items) { sp in
                                    SanPhamHinhAnhRow(
                                        sanPham: sp,
                                        uploading: uploadingId == sp.id,
                                        onPicked: { data, mime in Task { await upload(id: sp.id, data: data, mime: mime) } }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tìm món")
            .navigationTitle("Ảnh menu")
            .staffToolbar(isLoggedIn: $isLoggedIn)
        }
        .task { await load() }
        .alert("Đổi ảnh thất bại", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        if sanPhams.isEmpty { loading = true }
        sanPhams = await APIClient.shared.getSanPhamList()
        loading = false
    }

    private func upload(id: String, data: Data, mime: String) async {
        uploadingId = id
        defer { uploadingId = nil }
        let (url, message) = await APIClient.shared.uploadSanPhamHinhAnh(id: id, imageData: data, mimeType: mime)
        if let url {
            if let idx = sanPhams.firstIndex(where: { $0.id == id }) {
                let old = sanPhams[idx]
                // Backend giữ nguyên tên file (id.ext) mỗi lần đổi ảnh nên URL không đổi —
                // gắn query cache-bust để AsyncImage tải lại ngay.
                let bustedUrl = url + "?v=\(Int(Date().timeIntervalSince1970))"
                sanPhams[idx] = SanPhamDto(
                    id: old.id, ten: old.ten, ngungBan: old.ngungBan, tenNhomSanPham: old.tenNhomSanPham,
                    thuTu: old.thuTu, bienThe: old.bienThe, timKiem: old.timKiem, hinhAnh: bustedUrl)
            }
        } else {
            errorMessage = message ?? "Không cập nhật được ảnh."
        }
    }
}

private struct SanPhamHinhAnhRow: View {
    let sanPham: SanPhamDto
    let uploading: Bool
    let onPicked: (Data, String) -> Void

    @State private var showPicker = false
    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(sanPham.ten)
                if sanPham.hinhAnh == nil {
                    Text("Chưa có ảnh").font(.footnote).foregroundColor(.orange)
                }
            }
            Spacer()
            if uploading {
                ProgressView().frame(width: 36, height: 36)
            } else {
                Menu {
                    Button { showPicker = true } label: { Label("Chọn từ thư viện", systemImage: "photo.on.rectangle") }
                    Button { showCamera = true } label: { Label("Chụp ảnh", systemImage: "camera") }
                } label: {
                    Image(systemName: sanPham.hinhAnh == nil ? "plus.circle.fill" : "camera.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Đổi ảnh \(sanPham.ten)")
            }
        }
        .padding(.vertical, 2)
        .fullScreenCover(isPresented: $showPicker) {
            LibraryPicker { image in
                showPicker = false
                guard let image, let data = image.resizedForMenuUpload().jpegData(compressionQuality: 0.75) else { return }
                onPicked(data, "image/jpeg")
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let image, let data = image.resizedForMenuUpload().jpegData(compressionQuality: 0.75) else { return }
                onPicked(data, "image/jpeg")
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if let hinhAnh = sanPham.hinhAnh, let url = URL(string: hinhAnh) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(shape)
        } else {
            shape
                .fill(Color(.tertiarySystemFill))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
        }
    }
}

/// Bọc UIImagePickerController(sourceType: .photoLibrary) — picker ảnh mặc định của hệ thống.
struct LibraryPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPicked(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPicked(nil)
        }
    }
}

extension UIImage {
    /// Center-crop về tỉ lệ 3:4 rồi resize đúng 200x267 — khớp kích thước ảnh seed ban đầu.
    func resizedForMenuUpload() -> UIImage {
        let targetSize = CGSize(width: 200, height: 267)
        let targetRatio = targetSize.width / targetSize.height
        let sourceRatio = size.width / size.height

        var drawSize = targetSize
        if sourceRatio > targetRatio {
            drawSize.width = targetSize.height * sourceRatio
        } else {
            drawSize.height = targetSize.width / sourceRatio
        }
        let origin = CGPoint(x: (targetSize.width - drawSize.width) / 2, y: (targetSize.height - drawSize.height) / 2)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in draw(in: CGRect(origin: origin, size: drawSize)) }
    }
}
