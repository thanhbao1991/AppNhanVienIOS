import SwiftUI

@main
struct AppNhanVienIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Màu nền card (pastelBackground) cố định sáng bất kể theme — khoá Light để chữ
                // (.primary) không đổi trắng theo Dark Mode trên nền sáng (cùng lý do AppQuanLyIOS).
                .preferredColorScheme(.light)
        }
    }
}
