import Foundation

@MainActor
struct BranchTreeGroup: Identifiable {

    let id: UUID
    let title: String
    let root: String
    let model: BranchTreeModel
    let onRemove: () -> Void
}
