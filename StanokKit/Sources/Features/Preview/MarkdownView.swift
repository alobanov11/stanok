import SwiftUI

struct MarkdownView: View {

    private var sections: [MarkdownSection] {
        MarkdownSection.sections(from: blocks)
    }

    @AppStorage(PreviewTypography.Keys.markdownFontSize)
    private var fontSize = PreviewTypography.Defaults.markdownFontSize

    @AppStorage(PreviewTypography.Keys.markdownLineSpacing)
    private var lineSpacing = PreviewTypography.Defaults.markdownLineSpacing

    var body: some View {
        let markerWidths = ListMetrics.markerWidths(for: blocks, fontSize: fontSize)

        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections, id: \.firstID) { section in
                render(section, markerWidths)
                    .padding(.top, spacing(before: section.firstID))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    let blocks: [MarkdownBlock]

    @ViewBuilder
    private func render(_ section: MarkdownSection, _ markerWidths: [Int: CGFloat]) -> some View {
        switch section {
        case let .block(block):
            MarkdownBlockContentView(
                block: block,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                markerWidth: markerWidths[block.id] ?? 0
            )

        case let .quote(quoted):
            QuoteGroupView(
                blocks: quoted,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                markerWidths: markerWidths
            )

        case let .table(rows):
            TableGroupView(blocks: rows, fontSize: fontSize)
        }
    }

    private func spacing(before id: Int) -> CGFloat {
        guard id > 0, id < blocks.count else { return 0 }

        return CGFloat(BlockMargins.gap(
            before: blocks[id].kind,
            after: blocks[id - 1].kind,
            base: fontSize
        ))
    }
}
