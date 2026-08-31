import Foundation

struct CodeFold: Equatable, Sendable {

    let header: Int
    let end: Int
    let depth: Int

    init(header: Int, end: Int, depth: Int) {
        self.header = header
        self.end = end
        self.depth = depth
    }
}
