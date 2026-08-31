import Foundation

public struct GitTracking: Equatable, Sendable {

    public static let none = GitTracking(ahead: 0, behind: 0)
    public var hasDivergence: Bool { ahead > 0 || behind > 0 }
    public let ahead: Int
    public let behind: Int

    public init(ahead: Int, behind: Int) {
        self.ahead = ahead
        self.behind = behind
    }

    public static func parse(_ raw: String?) -> GitTracking {
        guard let raw else { return .none }

        let fields = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
        guard fields.count == 2, let ahead = Int(fields[0]), let behind = Int(fields[1])
        else { return .none }

        return GitTracking(ahead: ahead, behind: behind)
    }
}
