import Foundation

public struct GitCommitChanges: Equatable, Sendable {

    public var short: String {
        String(sha.prefix(7))
    }

    public var title: String {
        subject.isEmpty ? short : "\(short) · \(subject)"
    }

    public let sha: String
    public let subject: String
    public let changes: [GitChange]

    public init(sha: String, subject: String, changes: [GitChange]) {
        self.sha = sha
        self.subject = subject
        self.changes = changes
    }
}
