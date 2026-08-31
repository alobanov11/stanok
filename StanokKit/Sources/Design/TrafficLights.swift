import AppKit
import SwiftUI

struct TrafficLights: NSViewRepresentable {

    let isHidden: Bool

    func makeNSView(context: Context) -> TrafficLightsView {
        let view = TrafficLightsView()
        view.hidesButtons = isHidden
        return view
    }

    func updateNSView(_ view: TrafficLightsView, context: Context) {
        view.hidesButtons = isHidden
    }
}
