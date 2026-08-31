import Foundation

public struct AgentResumeAction: Equatable, Sendable {

    public let executable: String

    public let arguments: [String]

    public let runningProcessName: String?

    public let inSessionText: String?

    public init(
        executable: String,
        arguments: [String],
        runningProcessName: String? = nil,
        inSessionText: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.runningProcessName = runningProcessName
        self.inSessionText = inSessionText
    }
}
