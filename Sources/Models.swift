import Foundation

// Field name phải khớp tuyệt đối JSON backend trả về (không có CodingKeys riêng).

struct ApiEnvelope<T: Decodable>: Decodable {
    let isSuccess: Bool
    let message: String?
    let data: T?
    let warnings: [String]?
}

// ---- Auth ----

struct LoginRequest: Encodable { let taiKhoan: String; let matKhau: String; let thietBi: String?; let nenTang: String?; let thietBiId: String? }
struct RefreshRequest: Encodable { let refreshToken: String; let thietBi: String?; let nenTang: String?; let thietBiId: String? }

struct LoginResponse: Decodable {
    let thanhCong: Bool?
    let message: String?
    let token: String?
    let tenHienThi: String?
    let vaiTro: String?
    let refreshToken: String?
}

enum LoginResult {
    case success(LoginResponse)
    case rejected(String)
    case networkError
}

// Danh sách thiết bị đang đăng nhập (màn hình "Thiết bị đăng nhập") — giống trang Tài khoản Apple.

struct ChiTieuHangNgayDto: Decodable, Identifiable {
    let id: String
    let ten: String
    let soLuong: Double
    let donGia: Double
    let thanhTien: Double
    let ghiChu: String?
    let ngay: String?
    let ngayGio: String?
    let nguyenLieuId: String
    let billThang: Bool
    /// Tài khoản đã thêm dòng chi tiêu này — nil ở dữ liệu cũ trước khi có field.
    let tenTaiKhoan: String?
}

/// Đề xuất ngày mua tiếp theo của 1 nguyên liệu (GET /api/ChiTieuHangNgay/de-xuat-mua) — nguonAI=false

struct ChiTieuHangNgayCreateRequest: Encodable {
    let ten: String
    let soLuong: Double
    let donGia: Double
    let thanhTien: Double
    let ghiChu: String?
    let ngay: String
    let ngayGio: String
    let nguyenLieuId: String
    let billThang: Bool
}

// ---- Thêm chi tiêu từ ảnh hoá đơn (Gemini) ----

struct ReceiptParseLineDto: Decodable, Identifiable {
    var id: String { rawText }
    let rawText: String
    let soLuong: Double
    let donGia: Double
    let suggestedNguyenLieuId: String?
    let suggestedNguyenLieuTen: String?
    let suggestedFromLearnedAlias: Bool
}

struct ReceiptParseResultDto: Decodable {
    let lines: [ReceiptParseLineDto]
}

struct ChiTieuHangNgayBulkItemRequest: Encodable {
    let nguyenLieuId: String
    let ten: String?
    let soLuong: Double
    let donGia: Double
    let thanhTien: Double?
    let ghiChu: String?
    let billThang: Bool
    /// Có giá trị thì Backend tự học/ghi đè alias RawText → nguyenLieuId cho lần đọc ảnh sau —
    /// xem ChiTieuHangNgayBulkItemDto.RawText (Backend).
    let rawText: String?
}

struct ChiTieuHangNgayBulkCreateRequest: Encodable {
    let ngay: String
    let ngayGio: String?
    let billThang: Bool
    let items: [ChiTieuHangNgayBulkItemRequest]
}

struct NguyenLieuDto: Decodable, Identifiable {
    let id: String
    let ten: String
    let donViTinh: String?
    let giaNhap: Double
    var ngungSuDung: Bool
    let thuTu: Int
    /// Liên kết tồn kho bán hàng — màn "Cập nhật nguyên liệu" (NguyenLieuListView) KHÔNG cho sửa 2
    /// field này, chỉ đọc rồi gửi lại y nguyên khi Update, tránh vô tình xoá mất liên kết tồn kho
    /// (UpdateAsync bên Backend ghi đè toàn bộ field, thiếu 2 field này sẽ set về null/0).
    let nguyenLieuBanHangId: String?
    let heSoQuyDoiBanHang: Double?
    /// ⭐ ghim lên đầu màn Giá nguyên liệu — optional để không vỡ khi backend cũ chưa trả field.
    var yeuThich: Bool?
}

struct NguyenLieuCreateRequest: Encodable {
    let ten: String
}

struct SanPhamBienTheDto: Decodable, Identifiable, Hashable {
    let id: String
    let sanPhamId: String
    let tenBienThe: String
    let giaBan: Double
    let macDinh: Bool
}

struct SanPhamDto: Decodable, Identifiable {
    let id: String
    let ten: String
    let ngungBan: Bool
    let tenNhomSanPham: String?
    let thuTu: Int
    let bienThe: [SanPhamBienTheDto]
    /// Chuỗi token đã chuẩn hoá sẵn từ server (SanPhamSearchHelper.BuildTimKiem: tên không dấu +
    /// tên liền không cách + viết tắt tự nhận diện ("ts") + VietTat tự đặt tay ("cfk"...), nối bằng
    /// ";"). Dùng để tìm món khớp Desktop (SanPhamMatchHelper.Search) thay vì so trực tiếp `ten`.
    let timKiem: String?
    /// Ảnh menu cho AppDatHangIOS (app khách đặt hàng) — nil nếu chưa có ảnh khớp/upload.
    let hinhAnh: String?
}

// ---- Thống kê ngày ----

struct NamedAmountDto: Decodable, Identifiable {
    let ten: String
    let soTien: Double
    /// Khoá gộp thật (ChiTieuItemDto.NguyenLieuId ở backend) — dùng để khớp lại đúng nhóm khi bấm
    /// xem chi tiết, KHÔNG so bằng `ten` (chữ tự do, có thể lệch hoa/thường giữa các lần nhập).
    var nguyenLieuId: String? = nil
    var id: String { ten }
}

struct DoanhThuItemDto: Decodable, Identifiable {
    let ten: String
    let doanhThu: Double
    var id: String { ten }
}

struct KhachTienDto: Decodable, Identifiable {
    let khachHangId: String?
    let tenKhachHang: String
    let soTien: Double
    var id: String { tenKhachHang }
}

struct CongNoItemDto: Decodable, Identifiable {
    let khachHangId: String?
    let hoaDonId: String?
    let ngayGio: String?
    let tenKhachHang: String
    let soTienNo: Double
    var id: String { hoaDonId ?? (khachHangId ?? tenKhachHang) }
}

struct DonChuaThanhToanItemDto: Decodable, Identifiable {
    let khachHangId: String?
    let hoaDonId: String?
    let tenKhachHang: String
    let soTien: Double
    var id: String { hoaDonId ?? (khachHangId ?? tenKhachHang) }
}


struct TongNoItemDto: Decodable, Identifiable {
    let khachHangId: String?
    let tenKhachHang: String
    let tongConLai: Double
    var id: String { khachHangId ?? tenKhachHang }
}


struct ThongKeChiTieuDto: Decodable {
    let chiTieuNgay: Double
    let danhSachChiTieuNgay: [NamedAmountDto]
    let chiTieuThang: Double
    let danhSachChiTieuThang: [NamedAmountDto]
}

struct ThongKeCongNoDto: Decodable {
    let tongCongNoNgay: Double
    let danhSachCongNoNgay: [CongNoItemDto]
}

struct ThongKeThanhToanDto: Decodable {
    let tongTienMat: Double
    let tongChuyenKhoan: Double
    let danhSachTienMat: [NamedAmountDto]
}


struct ThongKeDoanhThuNgayDto: Decodable {
    let tongDoanhThu: Double
    let danhSach: [DoanhThuItemDto]
}

struct ThongKeTraNoNgayDto: Decodable {
    let tongTraNoTaiQuan: Double
    let tongTraNoShipper: Double
    let traNoTaiQuan: [KhachTienDto]
    let traNoShipper: [KhachTienDto]
}


struct ThongKeDonChuaThanhToanDto: Decodable {
    let tongChuaThanhToan: Double
    let danhSach: [DonChuaThanhToanItemDto]
}


struct TongNoDto: Decodable {
    let tongConLai: Double
    let danhSach: [TongNoItemDto]
}


struct ActionResult { let success: Bool; let message: String?; var warnings: [String] = [] }
