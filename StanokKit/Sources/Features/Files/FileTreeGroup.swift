import Foundation

@MainActor
struct FileTreeGroup: Identifiable {

    let id: UUID
    let title: String
    let model: FileTreeModel
    let onRemove: () -> Void
}
