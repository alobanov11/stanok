import AppKit
import SwiftUI

struct TrafficLights: NSViewRepresentable {

    let isHidden: Bool

    static func dismantleNSView(_ view: TrafficLightsView, coordinator: Void) {
        view.restore()
    }

    func makeNSView(context: Context) -> TrafficLightsView {
        let view = TrafficLightsView()
        view.hidesButtons = isHidden
        return view
    }

    func updateNSView(_ view: TrafficLightsView, context: Context) {
        view.hidesButtons = isHidden
    }
}
