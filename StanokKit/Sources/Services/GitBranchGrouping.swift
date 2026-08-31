import Foundation

public enum GitBranchGrouping {

    public struct RemoteGroup: Identifiable, Equatable, Sendable {

        public var id: String { name }

        public let name: String

        public let refs: [GitBranchRef]
    }

    public static func localMatches(_ refs: [GitBranchRef], search: String) -> [GitBranchRef] {
        filtered(refs.filter { $0.kind == .local }, search: search)
    }

    public static func remoteGroups(_ refs: [GitBranchRef], search: String) -> [RemoteGroup] {
        let remotes = filtered(refs.filter { $0.kind == .remote }, search: search)
        let grouped = Dictionary(grouping: remotes) { $0.remoteName ?? "" }

        return grouped.keys.sorted().map { RemoteGroup(name: $0, refs: grouped[$0] ?? []) }
    }

    private static func filtered(_ refs: [GitBranchRef], search: String) -> [GitBranchRef] {
        let sorted = refs.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }

        guard !search.isEmpty else { return sorted }

        return sorted.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }
}
