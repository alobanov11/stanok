import SwiftUI

struct PanelHeaderBackground: View {

    private static let fade: CGFloat = 18

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                VStack(spacing: 0) {
                    Color.black

                    LinearGradient(
                        colors: [.black, .black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: Self.fade)
                }
            }
            .allowsHitTesting(false)
    }
}
