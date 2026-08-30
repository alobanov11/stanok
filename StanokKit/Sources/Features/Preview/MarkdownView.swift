import SwiftUI

struct MarkdownView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                quoted(block)
                    .padding(.top, spacing(before: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    let blocks: [MarkdownBlock]

    @ViewBuilder
    private func quoted(_ block: MarkdownBlock) -> some View {
        if block.isQuoted {
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 3)

                content(block)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            content(block)
        }
    }

    @ViewBuilder
    private func content(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .heading(level):
            Text(block.text)
                .font(.system(
                    size: Self.headingSize(level),
                    weight: level == 1 ? .bold : .semibold
                ))

        case .paragraph:
            prose(block.text)

        case let .bullet(depth):
            item("•", block.text, depth)

        case let .numbered(ordinal, depth):
            item("\(ordinal).", block.text, depth)

        case let .continuation(depth):
            prose(block.text)
                .padding(.leading, Self.indent(depth) + 22)

        case let .code(lines):
            CodeBlockView(lines: lines, showsNumbers: false)
                .background(.black.opacity(0.22), in: .rect(cornerRadius: 8, style: .continuous))

        case .divider:
            Divider().padding(.vertical, 6)

        case let .tableRow(cells, isHeader):
            row(cells, isHeader)
        }
    }

    private func prose(_ text: AttributedString) -> some View {
        Text(text)
            .font(.system(size: 13))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func item(_ marker: String, _ text: AttributedString, _ depth: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(minWidth: 14, alignment: .trailing)

            prose(text)

            Spacer(minLength: 0)
        }
        .padding(.leading, Self.indent(depth))
    }

    private func row(_ cells: [AttributedString], _ isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.system(size: 12, weight: isHeader ? .semibold : .regular))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            if isHeader { Divider() }
        }
    }

    private static func isList(_ kind: MarkdownBlock.Kind) -> Bool {
        switch kind {
        case .bullet, .numbered, .continuation: true
        default: false
        }
    }

    private static func isTable(_ kind: MarkdownBlock.Kind) -> Bool {
        if case .tableRow = kind { return true }

        return false
    }

    private static func isCode(_ kind: MarkdownBlock.Kind) -> Bool {
        if case .code = kind { return true }

        return false
    }

    private static func heading(_ kind: MarkdownBlock.Kind) -> Int? {
        if case let .heading(level) = kind { return level }

        return nil
    }

    private static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 21
        case 2: 17
        case 3: 15
        default: 13
        }
    }

    private static func indent(_ depth: Int) -> CGFloat {
        CGFloat(max(depth - 1, 0)) * 20
    }

    private func spacing(before index: Int) -> CGFloat {
        guard index > 0 else { return 0 }

        let previous = blocks[index - 1].kind
        let current = blocks[index].kind

        if let level = Self.heading(current) { return level <= 2 ? 26 : 18 }
        if Self.heading(previous) != nil { return 7 }
        if Self.isTable(previous), Self.isTable(current) { return 0 }
        if Self.isList(previous), Self.isList(current) { return 5 }
        if Self.isCode(previous) || Self.isCode(current) { return 14 }

        return 13
    }

}
