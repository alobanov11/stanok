import SwiftUI

@MainActor
struct LiveSessionController {

    let store: SessionStore

    let dispatcher: TerminalCommandDispatcher

    let processTracker: TabProcessTracker

    let live: Binding<[TerminalSession.ID]>

    let selection: Binding<TerminalSession.ID?>

    func activate(_ id: TerminalSession.ID) {
        guard let root = store.root(of: id) else { return }

        let group = store.panes(of: root).map(\.id)

        for paneID in group where !live.wrappedValue.contains(paneID) {
            dispatcher.markAtPrompt(paneID)
        }

        live.wrappedValue.removeAll { group.contains($0) }
        live.wrappedValue.append(contentsOf: group)

        for paneID in group {
            processTracker.beginTracking(paneID)
        }

        trim(keeping: Set(group))
        store.select(id)
    }

    func reconcile(_ known: Set<TerminalSession.ID>) {
        let removed = live.wrappedValue.filter { !known.contains($0) }
        live.wrappedValue.removeAll { !known.contains($0) }

        for id in removed {
            processTracker.endTracking(id)
        }

        if let current = selection.wrappedValue, !known.contains(current) {
            selection.wrappedValue = nil
        }
    }

    func close(_ session: TerminalSession) {
        let fallback = neighbour(of: session)

        live.wrappedValue.removeAll { $0 == session.id }
        processTracker.endTracking(session.id)
        dispatcher.forget(session.id)

        withAnimation(.smooth(duration: 0.22)) {
            store.removeSession(session.id)

            if selection.wrappedValue == session.id { selection.wrappedValue = fallback }
        }

        store.select(fallback)
    }

    private func neighbour(of session: TerminalSession) -> TerminalSession.ID? {
        if
            let root = store.root(of: session.id),
            let sibling = store.panes(of: root).first(where: { $0.id != session.id }) {
            return sibling.id
        }

        return store.roots.first { $0.id != session.id }?.id
    }

    private func trim(keeping group: Set<TerminalSession.ID>) {
        guard live.wrappedValue.count > WorkspaceLayout.liveSessionLimit else { return }

        let overflow = live.wrappedValue.count - WorkspaceLayout.liveSessionLimit
        let evicted = live.wrappedValue.filter { !group.contains($0) }.prefix(overflow)

        for id in evicted {
            processTracker.endTracking(id)
        }

        live.wrappedValue.removeAll { evicted.contains($0) }
    }
}
