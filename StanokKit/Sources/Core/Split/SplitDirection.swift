import Foundation

public enum SplitDirection: String, Codable, CaseIterable, Sendable {

    case top

    case bottom

    case leading

    case trailing

    public var axis: SplitAxis {
        switch self {
        case .leading, .trailing: .horizontal
        case .top, .bottom: .vertical
        }
    }

    public var insertsFirst: Bool {
        switch self {
        case .top, .leading: true
        case .bottom, .trailing: false
        }
    }
}
