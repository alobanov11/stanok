import Foundation

public protocol AgentTouchesSource: Sendable {

    func touched(scope: String?) async -> (files: [AgentTouchedFile], directories: Set<String>)
}
