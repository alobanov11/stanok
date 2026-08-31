import Foundation

public struct AgentSessionKey: Hashable, Sendable {

    public let providerID: String

    public let sessionID: String

    public init(providerID: String, sessionID: String) {
        self.providerID = providerID
        self.sessionID = sessionID
    }
}
