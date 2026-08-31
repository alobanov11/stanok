import AppKit
import SwiftUI

struct SessionPersistence: ViewModifier {

    let store: SessionStore

    @Environment(\.scenePhase)
    private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }

                store.flushPendingSave()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSApplication.willResignActiveNotification)
            ) { _ in
                store.flushPendingSave()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSApplication.willTerminateNotification)
            ) { _ in
                store.flushPendingSave()
            }
    }
}
