import SwiftUI

@MainActor
struct LiveSessionController {

    let store: SessionStore
    let dispatcher: TerminalCommandDispatcher
    let processTracker: TabProcessTracker
    let live: Binding<[TerminalSession.ID]>
    let selection: Binding<TerminalSession.ID?>
    let navigators: PreviewNavigators
    let askSurface: (TerminalSession.ID) -> Void

    func activate(_ id: TerminalSession.ID) {
        if !live.wrappedValue.contains(id) { dispatcher.markAtPrompt(id) }

        live.wrappedValue.removeAll { $0 == id }
        live.wrappedValue.append(id)
        processTracker.beginTracking(id)

        // Почему: показанные терминалы нельзя выселять, их поверхности прямо на экране
        trim(keeping: Set(store.shown).union([id]))
        store.select(id)
    }

    func reconcile(_ known: Set<TerminalSession.ID>) {
        let removed = live.wrappedValue.filter { !known.contains($0) }
        live.wrappedValue.removeAll { !known.contains($0) }

        for id in removed {
            processTracker.endTracking(id)
            dispatcher.forget(id)
        }

        if let current = selection.wrappedValue, !known.contains(current) {
            selection.wrappedValue = nil
        }
    }

    func requestClose(_ session: TerminalSession) {
        guard live.wrappedValue.contains(session.id) else {
            close(session)
            return
        }

        askSurface(session.id)
    }

    func close(_ session: TerminalSession) {
        let wasSelected = selection.wrappedValue == session.id
        let fallback = neighbour(of: session)

        processTracker.endTracking(session.id)
        dispatcher.forget(session.id)

        // Почему: поверхность и раскладка должны исчезать одним движением, а не в два кадра
        withAnimation(.smooth(duration: 0.22)) {
            live.wrappedValue.removeAll { $0 == session.id }

            if let heir = store.removeSession(session.id) {
                navigators.inherit(heir, from: session.id)
            }

            if wasSelected { selection.wrappedValue = fallback }
        }

        if wasSelected { store.select(fallback) }
    }

    private func neighbour(of session: TerminalSession) -> TerminalSession.ID? {
        // Почему: соседом считается ближайший показанный терминал, а без него — любой другой
        if let shown = store.shown.first(where: { $0 != session.id }) { return shown }

        return store.sessions.first { $0.id != session.id }?.id
    }

    private func trim(keeping group: Set<TerminalSession.ID>) {
        guard live.wrappedValue.count > WorkspaceLayout.liveSessionLimit else { return }

        let overflow = live.wrappedValue.count - WorkspaceLayout.liveSessionLimit
        let evicted = live.wrappedValue.filter { !group.contains($0) }.prefix(overflow)

        for id in evicted {
            processTracker.endTracking(id)
            dispatcher.forget(id)
        }

        live.wrappedValue.removeAll { evicted.contains($0) }
    }
}
