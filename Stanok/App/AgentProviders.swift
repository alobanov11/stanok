import StanokAgents
import StanokKit

enum AgentProviders {

    static func registerAll(into registry: AgentSessionRegistry) {
        registry.register(ClaudeAgentProvider())
    }

    static func touchesSource() -> any AgentTouchesSource {
        ClaudeTouchesSource()
    }
}
