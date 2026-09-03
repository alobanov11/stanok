import CoreGraphics
import Testing

@testable import StanokKit

struct WorkspaceGeometryTests {

    @Test
    func aTallAreaCountsAsVertical() {
        #expect(WorkspaceGeometry.isVertical(CGSize(width: 1200, height: 1800)))
        #expect(!WorkspaceGeometry.isVertical(CGSize(width: 1800, height: 1200)))
    }

    @Test
    func aPreviewSharesTheAreaWhenTheStackingSideIsLongEnough() {
        let tall = CGSize(width: 1000, height: 1400)
        let short = CGSize(width: 1000, height: 600)

        #expect(WorkspaceGeometry.previewMode(hasPreview: true, size: tall) == .split)
        #expect(WorkspaceGeometry.previewMode(hasPreview: true, size: short) == .fullScreen)
    }

    @Test
    func aWideAreaKeepsTheColumnRule() {
        let wide = CGSize(width: 1600, height: 900)
        let narrow = CGSize(width: 900, height: 800)

        #expect(WorkspaceGeometry.previewMode(hasPreview: true, size: wide) == .split)
        #expect(WorkspaceGeometry.previewMode(hasPreview: true, size: narrow) == .fullScreen)
    }
}
