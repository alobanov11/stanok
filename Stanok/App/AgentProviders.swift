import StanokAgents
import StanokKit

enum AgentProviders {

    static func registerAll(into registry: AgentSessionRegistry) {
        registry.register(ClaudeAgentProvider())
    }
}
