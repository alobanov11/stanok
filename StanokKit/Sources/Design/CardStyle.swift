import SwiftUI

enum CardStyle: String, CaseIterable, Identifiable {

    case flat
    case raised
    case inset

    var id: String { rawValue }

    @ViewBuilder
    func background(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        switch self {
        case .flat:
            shape.fill(.regularMaterial)

        case .raised:
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(.white.opacity(0.10)) }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.28), radius: 10, y: 4)

        case .inset:
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(.black.opacity(0.16)) }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.black.opacity(0.45), .white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}
