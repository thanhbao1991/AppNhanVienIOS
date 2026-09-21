import XCTest
@testable import AppNhanVienIOS

final class FormattingTests: XCTestCase {
    func testMoneyDungDauChamNhom() {
        XCTAssertEqual(HoaDonFormatting.money(1500), "1.500đ")
        XCTAssertEqual(HoaDonFormatting.money(1234567), "1.234.567đ")
        XCTAssertEqual(HoaDonFormatting.money(0), "0đ")
    }

    func testMatchesSearchBoDauVaHoaThuong() {
        XCTAssertTrue("Cà Phê Đen".matchesSearch("ca phe"))
        XCTAssertFalse("Cà Phê Đen".matchesSearch("ca phe", diacriticInsensitive: false))
        XCTAssertTrue("Trà Xanh".matchesSearch(""))
    }

    func testAnyMatchesSearchBoQuaNil() {
        XCTAssertTrue(anyMatchesSearch("duong", "Đường cát", nil))
        XCTAssertFalse(anyMatchesSearch("sữa", "Đường cát", nil))
    }
}
