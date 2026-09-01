import Foundation
import StanokKit

public struct ClaudeTouchesSource: AgentTouchesSource {

    private let index = ClaudeEditIndex()
    private let root: URL

    public init(root: URL = ClaudeAgentProvider.defaultProjectsRoot) {
        self.root = root
    }

    public func touched() async -> (files: [AgentTouchedFile], directories: Set<String>) {
        let found = await index.touched(under: root)

        return (found.0, found.1)
    }
}
