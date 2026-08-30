import SwiftUI

struct CodeBlockView: View {

    private var gutterWidth: CGFloat {
        CGFloat(String(max(lines.count, 1)).count) * 8 + 4
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, tokens in
                    row(index, tokens)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .textSelection(.enabled)
    }

    let lines: [[CodeToken]]

    let showsNumbers: Bool

    private func row(_ index: Int, _ tokens: [CodeToken]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if showsNumbers {
                Text("\(index + 1)")
                    .foregroundStyle(.tertiary)
                    .frame(width: gutterWidth, alignment: .trailing)
                    .textSelection(.disabled)
            }

            line(tokens)
        }
        .font(CodeTheme.font)
    }

    private func line(_ tokens: [CodeToken]) -> Text {
        guard !tokens.isEmpty else { return Text(" ") }

        return tokens.reduce(Text("")) { result, token in
            result + Text(token.text).foregroundColor(CodeTheme.color(token.kind))
        }
    }
}
