import Foundation

public enum AgentSessionsLoadState: Equatable, Sendable {

    case loading

    case loaded([AgentSession])

    case failed(String)
}
