import Foundation

public protocol AgentTouchesSource: Sendable {

    func touched() async -> (files: [AgentTouchedFile], directories: Set<String>)
}
