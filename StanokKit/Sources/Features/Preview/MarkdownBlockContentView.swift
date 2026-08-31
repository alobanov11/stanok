import SwiftUI

struct MarkdownBlockContentView: View {

    var body: some View {
        switch block.kind {
        case let .heading(level):
            heading(level, block.text)

        case .paragraph:
            prose(block.text)

        case .bullet, .numbered:
            item(ListMetrics.markerText(block.kind), block.text, ListMetrics.depth(of: block.kind))

        case let .continuation(depth):
            prose(block.text)
                .padding(.leading, ListMetrics.continuationLeading(
                    depth: depth,
                    markerWidth: markerWidth
                ))

        case let .code(lines):
            CodeBlockView(lines: lines, showsNumbers: false)
                .background(.black.opacity(0.22), in: .rect(cornerRadius: 8, style: .continuous))

        case .divider:
            Divider()

        case .tableRow:
            EmptyView()
        }
    }

    let block: MarkdownBlock

    let fontSize: Double

    let lineSpacing: Double

    let markerWidth: CGFloat

    private func prose(_ text: AttributedString) -> some View {
        Text(LinkStyle.styled(text))
            .font(.system(size: fontSize))
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .pointerStyle(LinkStyle.containsLink(text) ? .link : nil)
    }

    private func item(_ marker: String, _ text: AttributedString, _ depth: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ListMetrics.Metric.markerSpacing) {
            Text(marker)
                .font(.system(size: fontSize))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: markerWidth, alignment: .trailing)

            prose(text)

            Spacer(minLength: 0)
        }
        .padding(.leading, ListMetrics.indent(depth: depth))
    }

    @ViewBuilder
    private func heading(_ level: Int, _ text: AttributedString) -> some View {
        switch level {
        case 1, 2, 3:
            Text(text)
                .font(.system(
                    size: Self.headingSize(level, base: fontSize),
                    weight: level == 1 ? .bold : .semibold
                ))

        case 4:
            Text(text)
                .font(.system(size: fontSize * 1.05, weight: .semibold))

        case 5:
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.secondary)

        default:
            Text(text)
                .font(.system(size: fontSize * 0.92, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
                .textCase(.uppercase)
        }
    }

    private static func headingSize(_ level: Int, base: Double) -> CGFloat {
        switch level {
        case 1: base * 1.6
        case 2: base * 1.3
        default: base * 1.15
        }
    }
}
