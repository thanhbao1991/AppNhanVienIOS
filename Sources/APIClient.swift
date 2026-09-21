import Foundation
import UIKit

/// Port 1:1 từ AppMobileAndroid/ApiClient.kt (OkHttp+Gson → URLSession+Codable). Bearer token
/// tự đính kèm, tự refresh 1 lần khi gặp 401 rồi retry đúng request gốc — khớp hành vi
/// authenticator bên Android.
actor APIClient {
    static let shared = APIClient()

    private func jsonBody<T: Encodable>(_ obj: T) -> Data {
        try! JSONEncoder().encode(obj)
    }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil, authorized: Bool = true) -> URLRequest {
        var req = URLRequest(url: URL(string: Prefs.apiBase + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token = Prefs.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    // Refresh đang chạy dở (nếu có) — nhiều màn hình bắn request song song trên cùng actor này (vd.
    // ThongKeView.load() gọi 8 endpoint /api/ThongKe cùng lúc bằng "async let"). actor Swift MẶC ĐỊNH
    // reentrant tại các điểm await — nếu cả 8 request cùng dính 401 (token hết hạn), mỗi request tự
    // gọi doRefresh() riêng thì y hệt lỗi từng gặp bên AppShipperAndroid: backend xoay vòng refresh
    // token kiểu one-time-use (AuthService.RefreshAsync ghi đè TokenHash ngay khi dùng), request thắng
    // race lưu token mới xong thì các request thua bị BE từ chối refresh token cũ (đã tiêu) → 401 →
    // Prefs.clear() xoá sạch luôn token mới vừa refresh thành công, bắt đăng xuất dù phiên còn sống.
    // Gộp lại 1 Task refresh dùng chung: request đến sau thấy đang có refresh dở thì CHỜ kết quả đó
    // thay vì tự gọi network riêng.
    private var refreshTask: Task<String?, Never>?

    private func send(_ req: URLRequest, allowRefresh: Bool = true) async -> (Data?, HTTPURLResponse?) {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let http = resp as? HTTPURLResponse
            if http?.statusCode == 401, allowRefresh {
                let usedToken = req.value(forHTTPHeaderField: "Authorization")?
                    .replacingOccurrences(of: "Bearer ", with: "")
                if let newToken = await refreshTokenCoalesced(previousToken: usedToken) {
                    var retried = req
                    retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    return await send(retried, allowRefresh: false)
                }
                // Refresh thất bại thật (token bị thu hồi/hết hạn ở nơi khác) — không có gì tự cứu
                // được nữa, phải đưa app quay về màn hình login thay vì để lỗi 401 lặng lẽ.
                Prefs.clear()
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
            return (data, http)
        } catch {
            return (nil, nil)
        }
    }

    /// Double-check trước khi refresh: nếu token hiện tại đã khác token vừa dùng lúc 401 nghĩa là 1
    /// request khác vừa refresh xong — dùng luôn, khỏi gọi /api/auth/refresh thừa. Nếu chưa có ai
    /// refresh, request đầu tiên tạo Task, các request đến sau (kể cả do actor reentrant) chỉ await
    /// chung Task đó thay vì tạo Task/network call mới.
    private func refreshTokenCoalesced(previousToken: String?) async -> String? {
        if let current = Prefs.token, !current.isEmpty, current != previousToken { return current }

        if let existing = refreshTask {
            return await existing.value
        }

        guard let refreshToken = Prefs.refreshToken else { return nil }
        let task = Task<String?, Never> { await self.doRefresh(refreshToken) }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func doRefresh(_ refreshToken: String) async -> String? {
        let req = makeRequest("/api/auth/refresh", method: "POST",
                               body: jsonBody(RefreshRequest(refreshToken: refreshToken, thietBi: deviceName(), nenTang: "iOS", thietBiId: deviceId())),
                               authorized: false)
        let (data, http) = await send(req, allowRefresh: false)
        guard let data, http?.statusCode == 200,
              let env = try? JSONDecoder().decode(ApiEnvelope<LoginResponse>.self, from: data),
              env.isSuccess, let resp = env.data, let token = resp.token else { return nil }
        Prefs.saveSession(token: token, refreshToken: resp.refreshToken, displayName: resp.tenHienThi)
        return token
    }

    func login(taiKhoan: String, matKhau: String) async -> LoginResult {
        let req = makeRequest("/api/auth/login", method: "POST",
                               body: jsonBody(LoginRequest(taiKhoan: taiKhoan, matKhau: matKhau, thietBi: deviceName(), nenTang: "iOS", thietBiId: deviceId())),
                               authorized: false)
        let (data, _) = await send(req, allowRefresh: false)
        guard let data else { return .networkError }
        guard let env = try? JSONDecoder().decode(ApiEnvelope<LoginResponse>.self, from: data) else { return .networkError }
        if !env.isSuccess { return .rejected(env.message ?? "Sai tài khoản hoặc mật khẩu.") }
        guard let resp = env.data else { return .networkError }
        return .success(resp)
    }

    private func deviceName() -> String {
        UIDevice.current.name
    }

    /// Định danh ổn định của máy (khác deviceName() — tên máy do người dùng đặt, dễ trùng nếu 2 máy
    /// cùng chưa đổi tên mặc định "iPhone", từng khiến backend dedupe nhầm 2 máy là 1, thu hồi phiên
    /// lẫn nhau — xem incident_ios_multidevice_same_name_session_kick). identifierForVendor ổn định
    /// qua các lần mở app, chỉ đổi nếu gỡ hết app của cùng vendor.
    private func deviceId() -> String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    func getChiTieuByDay(_ dateIso: String) async -> [ChiTieuHangNgayDto] {
        let req = makeRequest("/api/ChiTieuHangNgay?ngay=\(dateIso)")
        let (data, _) = await send(req)
        guard let data, let env = try? JSONDecoder().decode(ApiEnvelope<[ChiTieuHangNgayDto]>.self, from: data), env.isSuccess else { return [] }
        return env.data ?? []
    }

    func createChiTieu(_ body: ChiTieuHangNgayCreateRequest) async -> ActionResult {
        let req = makeRequest("/api/ChiTieuHangNgay", method: "POST", body: jsonBody(body))
        return await executeAction(req)
    }

    /// Đọc ảnh hoá đơn qua Gemini — multipart/form-data field "image". Không dùng makeRequest (JSON
    /// mặc định), tự dựng multipart body rồi gọi chung send() để có sẵn refresh-token/retry 401.
    func parseReceipt(imageData: Data, mimeType: String = "image/jpeg") async -> (result: ReceiptParseResultDto?, message: String?) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: URL(string: Prefs.apiBase + "/api/ChiTieuHangNgay/parse-receipt")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = Prefs.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let (data, _) = await send(req)
        guard let data else { return (nil, "Không có phản hồi từ server.") }
        guard let env = try? JSONDecoder().decode(ApiEnvelope<ReceiptParseResultDto>.self, from: data) else {
            return (nil, "Không đọc được phản hồi từ server.")
        }
        return (env.data, env.isSuccess ? nil : (env.message ?? "Đọc ảnh thất bại."))
    }

    func bulkCreateChiTieu(_ body: ChiTieuHangNgayBulkCreateRequest) async -> ActionResult {
        let req = makeRequest("/api/ChiTieuHangNgay/bulk", method: "POST", body: jsonBody(body))
        return await executeAction(req)
    }

    func updateChiTieu(id: String, _ body: ChiTieuHangNgayCreateRequest) async -> ActionResult {
        let req = makeRequest("/api/ChiTieuHangNgay/\(id)", method: "PUT", body: jsonBody(body))
        return await executeAction(req)
    }

    func deleteChiTieu(id: String) async -> ActionResult {
        let req = makeRequest("/api/ChiTieuHangNgay/\(id)", method: "DELETE")
        return await executeAction(req)
    }

    /// Nguyên liệu NHẬP dùng cho form Thêm chi tiêu — khớp desktop ChiTieuInputPanel (GET /api/NguyenLieu).
    func getNguyenLieu() async -> [NguyenLieuDto] {
        let req = makeRequest("/api/NguyenLieu")
        let (data, _) = await send(req)
        guard let data, let env = try? JSONDecoder().decode(ApiEnvelope<[NguyenLieuDto]>.self, from: data), env.isSuccess else { return [] }
        return env.data ?? []
    }

    /// Thêm nguyên liệu mới ngay trong form Thêm chi tiêu — chỉ Ten là bắt buộc phía server
    /// (NguyenLieuService.CreateAsync), các field khác server tự để mặc định (0/false/null).
    func createNguyenLieu(ten: String) async -> (success: Bool, message: String?, nguyenLieu: NguyenLieuDto?) {
        let body = NguyenLieuCreateRequest(ten: ten)
        let req = makeRequest("/api/NguyenLieu", method: "POST", body: jsonBody(body))
        let (data, _) = await send(req)
        guard let data, let env = try? JSONDecoder().decode(ApiEnvelope<NguyenLieuDto>.self, from: data) else {
            return (false, "Không có phản hồi từ server.", nil)
        }
        return (env.isSuccess, env.message, env.data)
    }

    /// Parse thô bằng JSONSerialization (không ràng buộc shape "data") — khớp cách Kotlin dùng
    /// JsonParser thô cho các action, tránh Decodable fail nếu "data" trả về khác dự đoán.
    private func executeAction(_ req: URLRequest) async -> ActionResult {
        let (data, _) = await send(req)
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ActionResult(success: false, message: "Không có phản hồi từ server.")
        }
        let success = (obj["isSuccess"] as? Bool) ?? false
        let message = obj["message"] as? String
        let warnings = (obj["warnings"] as? [String]) ?? []
        return ActionResult(success: success, message: message, warnings: warnings)
    }
}
