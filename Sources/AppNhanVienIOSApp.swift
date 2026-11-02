import SwiftUI

@main
struct AppNhanVienIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                // App chưa thiết kế cho Dark Mode (màu thương hiệu, biểu đồ) — khoá Light.
                .preferredColorScheme(.light)
        }
    }
}
