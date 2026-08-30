import SwiftUI

struct TableGroupView: View {

    private var rows: [(cells: [AttributedString], isHeader: Bool)] {
        blocks.compactMap { block in
            if case let .tableRow(cells, isHeader) = block.kind { (cells, isHeader) } else { nil }
        }
    }

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(
                                size: fontSize * 0.92,
                                weight: row.isHeader ? .semibold : .regular
                            ))
                            .lineSpacing(3)
                    }
                }
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) {
                    if row.isHeader { Divider() }
                }
            }
        }
    }

    let blocks: [MarkdownBlock]

    let fontSize: Double

}
