import SwiftUI

struct QuoteGroupView: View {

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(.quaternary)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    MarkdownBlockContentView(
                        block: block,
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        markerWidth: markerWidths[block.id] ?? 0
                    )
                    .padding(.top, index == 0 ? 0 : gap(at: index))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    let blocks: [MarkdownBlock]

    let fontSize: Double

    let lineSpacing: Double

    let markerWidths: [Int: CGFloat]

    private func gap(at index: Int) -> CGFloat {
        CGFloat(BlockMargins.gap(
            before: blocks[index].kind,
            after: blocks[index - 1].kind,
            base: fontSize
        ))
    }
}
