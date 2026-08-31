import Testing

import StanokKit

struct FilePanelModeTransitionTests {

    @Test
    func requestingTheOpenModeAgainCloses() {
        let transition = FilePanelModeTransition.resolve(current: .all, requested: .all)

        #expect(transition == .closes)
        #expect(transition.nextMode == nil)
        #expect(transition.animates)
    }

    @Test
    func requestingADifferentModeSwitchesWithoutAnimating() {
        let transition = FilePanelModeTransition.resolve(current: .all, requested: .changes)

        #expect(transition == .switches(.changes))
        #expect(transition.nextMode == .changes)
        #expect(!transition.animates)
    }

    @Test
    func requestingAModeFromClosedOpensAndAnimates() {
        let transition = FilePanelModeTransition.resolve(current: nil, requested: .changes)

        #expect(transition == .opens(.changes))
        #expect(transition.nextMode == .changes)
        #expect(transition.animates)
    }
}
