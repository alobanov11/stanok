import SwiftUI
import UniformTypeIdentifiers

struct PaneDropDelegate: DropDelegate {

    let target: TerminalSession.ID

    @Binding
    var dragged: TerminalSession.ID?

    @Binding
    var highlighted: TerminalSession.ID?

    let swap: (TerminalSession.ID, TerminalSession.ID) -> Void

    // Почему: чужой текстовый drop не должен тасовать терминалы, тянуть можно только свои
    func validateDrop(info: DropInfo) -> Bool {
        guard let dragged, dragged != target else { return false }

        return info.hasItemsConforming(to: [.plainText])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }

        highlighted = target
    }

    func dropExited(info: DropInfo) {
        guard highlighted == target else { return }

        highlighted = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragged, dragged != target else { return false }

        guard let provider = info.itemProviders(for: [.plainText]).first else {
            reset()

            return false
        }

        // Почему: отменённый drag оставляет прежний dragged, поэтому сверяем сам перенесённый ID
        provider.loadObject(ofClass: NSString.self) { object, _ in
            let carried = (object as? NSString).flatMap { UUID(uuidString: $0 as String) }

            Task { @MainActor in
                defer { reset() }

                guard carried == dragged else { return }

                swap(dragged, target)
            }
        }

        return true
    }

    private func reset() {
        dragged = nil
        highlighted = nil
    }
}
