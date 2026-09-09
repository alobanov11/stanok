import SwiftUI

enum CardStyle: String, CaseIterable, Identifiable {

    case flat
    case raised
    case inset

    var id: String {
        rawValue
    }

    @ViewBuilder
    func background(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch self {
        case .flat:
            shape.fill(.regularMaterial)

        case .raised:
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(Palette.raised) }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [Palette.edge, Palette.stroke.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
                .compositingGroup()
                .shadow(color: Palette.shadow, radius: 10, y: 4)

        case .inset:
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(Palette.inset) }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [Palette.insetStrong, Palette.stroke],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}
