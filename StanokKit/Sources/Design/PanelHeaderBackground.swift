import SwiftUI

struct PanelHeaderBackground: View {

    var body: some View {
        // Почему: размытие обрывается видимой линией, поэтому текст гасим градиентом
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.55), location: 0),
                .init(color: .black.opacity(0.45), location: 0.45),
                .init(color: .black.opacity(0.2), location: 0.78),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
