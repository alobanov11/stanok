import Foundation

public struct AgentResumeAction: Equatable, Sendable {

    public let executable: String

    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}
