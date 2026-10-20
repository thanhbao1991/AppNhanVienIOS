import SwiftUI

extension View {
    /// Tô nền navigation bar theo màu brand.
    func brandToolbarBackground() -> some View {
        self.toolbarBackground(Color.brandPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
