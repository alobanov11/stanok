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
        let transition = FilePanelModeTransition.resolve(current: .all, requested: .git)

        #expect(transition == .switches(.git))
        #expect(transition.nextMode == .git)
        #expect(!transition.animates)
    }

    @Test
    func requestingAModeFromClosedOpensAndAnimates() {
        let transition = FilePanelModeTransition.resolve(current: nil, requested: .git)

        #expect(transition == .opens(.git))
        #expect(transition.nextMode == .git)
        #expect(transition.animates)
    }
}
