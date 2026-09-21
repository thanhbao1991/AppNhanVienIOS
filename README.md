# AppNhanVienIOS

App iOS (SwiftUI) **dành cho nhân viên** quán Đenn Coffee — chỉ có **1 màn hình: Chi Tiêu**. Gọi thẳng
`https://api.denncoffee.uk` (TraSuaApp.Backend), quyền `StaffOnly` (tài khoản khách hàng không dùng được).

Tính năng:
- Danh sách chi tiêu theo ngày + tìm kiếm; tổng Ngày / Tháng / cả ngày.
- Thêm / sửa / xoá (có xác nhận) chi tiêu; thêm nguyên liệu mới ngay trong form.
- Quét ảnh hoá đơn (thư viện hoặc camera) → Gemini đọc → duyệt/sửa → lưu hàng loạt (`/api/ChiTieuHangNgay/bulk`).
- Đăng nhập bằng tài khoản nhân viên (form thủ công, không hardcode mật khẩu). Nút 👤 góc trái = Đăng xuất.

Code tách từ tab Chi tiêu của `AppQuanLyIOS`; **bundle ID riêng** `uk.denncoffee.appnhanvienios`, tên hiển thị "Chi Tiêu".
Dùng chung icon với AppQuanLyIOS tạm thời — đổi `Assets.xcassets/AppIcon.appiconset` nếu cần phân biệt trên màn hình chính.

## Build (không cần Mac)
CI `.github/workflows/build-ios.yml` (macOS runner) chạy test + build ra `AppNhanVienIOS-unsigned.ipa` (chưa ký),
cài lên iPhone bằng Sideloadly giống AppQuanLyIOS.
