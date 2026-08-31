import Foundation

struct GitTreeNode: Identifiable, Equatable {

    var id: String { relativePath }
    let name: String
    let url: URL
    let isDirectory: Bool
    let depth: Int
    let relativePath: String
    let status: GitFileStatus?
    let children: [GitTreeNode]
}
