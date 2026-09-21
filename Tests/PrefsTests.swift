import XCTest
@testable import AppNhanVienIOS

final class PrefsTests: XCTestCase {
    override func setUp() { Prefs.clear(); Prefs.manualLogout = false }
    override func tearDown() { Prefs.clear(); Prefs.manualLogout = false }

    func testSaveSessionVaClear() {
        XCTAssertFalse(Prefs.isLoggedIn)
        Prefs.saveSession(token: "t1", refreshToken: "r1", displayName: "Nhân viên A")
        XCTAssertTrue(Prefs.isLoggedIn)
        XCTAssertEqual(Prefs.refreshToken, "r1")
        XCTAssertEqual(Prefs.displayName, "Nhân viên A")
        Prefs.clear()
        XCTAssertFalse(Prefs.isLoggedIn)
    }
}
