import Foundation

@MainActor
final class TerminalSnapshotController {

    var read: (() -> String?)?
}
