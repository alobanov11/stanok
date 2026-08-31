import SwiftUI

struct CodeBlockView: View {

    private enum Metric {

        static let ribbonWidth: CGFloat = 3
        static let foldWidth: CGFloat = 11
        static let rowPadding: CGFloat = 2
        static let gutterGap: CGFloat = 8
    }

    private var gutterWidth: CGFloat {
        CGFloat(String(max(lines.count, 1)).count) * 8 + 4
    }

    private var visible: [Int] {
        folds.visibleLines(count: lines.count, folded: folded)
    }

    private var resolvedFamily: String {
        fontFamily.isEmpty ? terminalFamily : fontFamily
    }

    @AppStorage(PreviewTypography.Keys.codeFontSize)
    private var fontSize = PreviewTypography.Defaults.codeFontSize

    @AppStorage(PreviewTypography.Keys.codeFontFamily)
    private var fontFamily = PreviewTypography.Defaults.codeFontFamily

    @State
    private var terminalFamily = ConfigFile.value(for: "font-family") ?? ""

    @State
    private var folds = CodeFoldMap.empty

    @State
    private var folded: Set<Int> = []

    @State
    private var hovered: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(visible, id: \.self) { index in
                    row(index, lines[index])
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, showsNumbers ? 0 : 12)
        }
        .textSelection(.enabled)
        .task { buildFolds() }
        .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
            terminalFamily = ConfigFile.value(for: "font-family") ?? ""
        }
    }

    private var foldedMarker: some View {
        Text("⋯")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .background(.white.opacity(0.14), in: .capsule)
            .padding(.leading, 6)
            .textSelection(.disabled)
    }

    let lines: [[CodeToken]]
    let showsNumbers: Bool

    var changes: [Int: LineChange] = [:]
}

private extension CodeBlockView {

    func row(_ index: Int, _ tokens: [CodeToken]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if showsNumbers {
                number(index)
                foldRibbon(index)
                changeRibbon(index)
            }

            line(tokens)
                .padding(.leading, showsNumbers ? Metric.gutterGap : 0)

            if folded.contains(index) {
                foldedMarker
            }
        }
        .padding(.vertical, Metric.rowPadding)
        .font(CodeTheme.font(size: fontSize, family: resolvedFamily))
    }

    func number(_ index: Int) -> some View {
        Text("\(index + 1)")
            .foregroundStyle(.tertiary)
            .frame(width: gutterWidth, alignment: .trailing)
            .padding(.leading, 12)
            .textSelection(.disabled)
    }

    @ViewBuilder
    func foldRibbon(_ index: Int) -> some View {
        let fold = folds.fold(startingAt: index)
        let owner = folds.owner(of: index)
        let scope = fold ?? owner
        let isLit = hovered != nil && hovered == scope?.header

        ZStack {
            if owner != nil || fold != nil {
                Capsule()
                    .fill(.white.opacity(isLit ? 0.3 : 0.12))
                    .frame(width: Metric.ribbonWidth)
                    .frame(maxHeight: .infinity)
            }

            if let fold {
                Image(systemName: folded.contains(index) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.secondary)
                    .opacity(isLit || folded.contains(index) ? 1 : 0)
                    .textSelection(.disabled)
                    .accessibilityLabel(folded.contains(index) ? "Развернуть" : "Свернуть")
                    .help(folded.contains(index) ? "Развернуть блок" : "Свернуть блок")
                    .allowsHitTesting(false)
                    .background(.clear)
                    .id(fold.header)
            }
        }
        .frame(width: Metric.foldWidth)
        .padding(.leading, Metric.gutterGap)
        .contentShape(.rect)
        .onHover { hovering in hovered = hovering ? scope?.header : nil }
        .onTapGesture { toggle(scope?.header) }
    }

    func changeRibbon(_ index: Int) -> some View {
        let change = changes[index + 1]

        return Rectangle()
            .fill(change == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.accentColor))
            .frame(width: Metric.ribbonWidth)
            .frame(maxHeight: change == .removed ? 2 : .infinity, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.leading, 6)
            .help(hint(for: change))
    }

    func line(_ tokens: [CodeToken]) -> Text {
        guard !tokens.isEmpty else { return Text(" ") }

        return tokens.reduce(Text("")) { result, token in
            result + Text(token.text).foregroundColor(CodeTheme.color(token.kind))
        }
    }

    func hint(for change: LineChange?) -> String {
        switch change {
        case .added: "Строка добавлена"
        case .modified: "Строка изменена"
        case .removed: "Ниже удалены строки"
        case nil: ""
        }
    }

    func toggle(_ header: Int?) {
        guard let header, folds.fold(startingAt: header) != nil else { return }

        withAnimation(.smooth(duration: 0.16)) {
            if folded.contains(header) {
                folded.remove(header)
            } else {
                folded.insert(header)
            }
        }
    }

    func buildFolds() {
        guard showsNumbers, folds.isEmpty else { return }

        folds = CodeFoldMap(folds: CodeFolding.folds(for: lines))
    }
}
