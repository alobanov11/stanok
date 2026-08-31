import Foundation

public struct GitCommandOutcome: Equatable, Sendable {

    public let succeeded: Bool
    public let message: String

    public init(succeeded: Bool, message: String) {
        self.succeeded = succeeded
        self.message = message
    }

    public static func make(
        exitCode: Int32,
        standardOutput: Data,
        standardError: String
    ) -> GitCommandOutcome {
        let stdout = (String(data: standardOutput, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let text = standardError.isEmpty ? stdout : standardError

        return GitCommandOutcome(succeeded: exitCode == 0, message: text)
    }
}
