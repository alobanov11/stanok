import SwiftUI

struct InspectorSync: ViewModifier {

    let state: InspectorState
    let folder: URL?
    let gitRoot: String?
    let snapshot: GitSnapshot?
    let branchSnapshot: GitBranchSnapshot?
    let folders: Set<URL>
    let gitRoots: Set<String>

    func body(content: Content) -> some View {
        content
            .onChange(of: snapshot?.gitDirectory, initial: true) { _, directory in
                guard let folder else { return }

                state.fileTree(for: folder).updateGitDirectory(directory)
            }
            .onChange(of: snapshot, initial: true) { _, snapshot in
                guard let gitRoot else { return }

                state.changeTree(for: gitRoot).apply(snapshot)
            }
            .onChange(of: branchSnapshot, initial: true) { _, branchSnapshot in
                guard let gitRoot else { return }

                state.branchTree(for: gitRoot).apply(branchSnapshot)
            }
            .onChange(of: folders, initial: true) { _, folders in
                state.prune(folders: folders, gitRoots: gitRoots)
            }
            .onChange(of: gitRoots) { _, gitRoots in
                state.prune(folders: folders, gitRoots: gitRoots)
            }
    }
}
