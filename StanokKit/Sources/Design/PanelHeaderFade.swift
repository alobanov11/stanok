import SwiftUI

struct PanelHeaderFade: View {

    var body: some View {
        // Почему: текст растворяется под шапкой, тёмная плашка вместо этого читается тенью
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.35), location: 0.7),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: WorkspaceLayout.headerHeight)

            Color.black
        }
    }
}
