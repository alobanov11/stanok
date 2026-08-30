import Foundation

public struct PinnedSession: Identifiable, Equatable {

    public var id: TerminalSession.ID { session.id }

    public let repository: Repository

    public let session: TerminalSession

    public init(repository: Repository, session: TerminalSession) {
        self.repository = repository
        self.session = session
    }
}
