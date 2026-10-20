import SwiftUI
import Photos

/// TẠM THỜI (2026-10-20): nhập lại ảnh/video từ bản backup iPhone đã giải nén trên máy quầy (.138)
/// vào thẳng thư viện Ảnh chính, giữ ngày chụp gốc, ghép lại Live Photo (HEIC + MOV cùng tên).
/// Máy quầy chạy server LAN liệt kê `/list` + phát file `/f/<đường dẫn>`. Xoá màn này khi xong việc.
struct NhapAnhView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nhapAnh.server") private var server = "http://192.168.1.12:8899"
    @AppStorage("nhapAnh.done") private var doneRaw = ""
    @State private var items: [Item] = []
    @State private var running = false
    @State private var status = ""
    @State private var errors = 0

    struct Item: Decodable, Hashable {
        let id: String
        let photo: String?
        let video: String?
        let t: Double
    }

    private var doneSet: Set<String> { Set(doneRaw.split(separator: "\n").map(String.init)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Máy quầy") {
                    TextField("Địa chỉ", text: $server)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(running)
                }
                Section {
                    let done = doneSet.count
                    if !items.isEmpty {
                        ProgressView(value: Double(done), total: Double(items.count))
                        Text("\(done)/\(items.count) đã lưu vào Ảnh" + (errors > 0 ? " · \(errors) lỗi" : ""))
                    }
                    if !status.isEmpty { Text(status).font(.footnote).foregroundColor(.secondary) }
                    Button(running ? "Đang nhập… (để app mở, màn hình sáng)" : "Bắt đầu nhập ảnh") {
                        Task { await run() }
                    }
                    .disabled(running)
                }
                Section {
                    Text("Giữ iPhone và máy quầy cùng Wi-Fi. Có thể dừng giữa chừng, bấm lại sẽ chạy tiếp phần còn thiếu.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nhập ảnh từ máy quầy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }.disabled(running)
                }
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func run() async {
        running = true
        errors = 0
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            running = false
            UIApplication.shared.isIdleTimerDisabled = false
        }

        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else {
            status = "Chưa cho phép lưu vào Ảnh — mở Cài đặt → Chi Tiêu → Ảnh."
            return
        }
        guard let base = URL(string: server.trimmingCharacters(in: .whitespaces)) else {
            status = "Địa chỉ không hợp lệ"
            return
        }

        do {
            status = "Đang lấy danh sách…"
            let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("list"))
            items = try JSONDecoder().decode([Item].self, from: data)
        } catch {
            status = "Không kết nối được máy quầy: \(error.localizedDescription)"
            return
        }

        var done = doneSet
        for item in items where !done.contains(item.id) {
            status = "Đang lưu \(item.id)…"
            do {
                try await save(item, base: base)
                done.insert(item.id)
                doneRaw = done.sorted().joined(separator: "\n")
            } catch {
                errors += 1
                status = "Lỗi \(item.id): \(error.localizedDescription)"
            }
        }
        status = errors == 0 ? "Xong ✅" : "Xong, còn \(errors) lỗi — bấm lại để thử lại phần lỗi."
    }

    private func download(_ path: String, base: URL) async throws -> URL {
        var url = base.appendingPathComponent("f")
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        let (tmp, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        // Photos nhận dạng loại file qua đuôi — giữ đúng đuôi gốc.
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + (path as NSString).pathExtension)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest
    }

    private func save(_ item: Item, base: URL) async throws {
        let photoURL = try await item.photo.asyncMap { try await download($0, base: base) }
        let videoURL = try await item.video.asyncMap { try await download($0, base: base) }
        defer {
            [photoURL, videoURL].compactMap { $0 }.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        let date = Date(timeIntervalSince1970: item.t)

        func create(photo: URL?, video: URL?, live: Bool) async throws {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.creationDate = date
                if let photo { req.addResource(with: .photo, fileURL: photo, options: nil) }
                if let video { req.addResource(with: live ? .pairedVideo : .video, fileURL: video, options: nil) }
            }
        }

        if let photoURL, let videoURL {
            // Live Photo: nếu metadata không khớp nhau thì Photos từ chối — lưu riêng ảnh tĩnh.
            do { try await create(photo: photoURL, video: videoURL, live: true) }
            catch { try await create(photo: photoURL, video: nil, live: false) }
        } else {
            try await create(photo: photoURL, video: videoURL, live: false)
        }
    }
}

private extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        switch self {
        case .some(let value): return try await transform(value)
        case .none: return nil
        }
    }
}
