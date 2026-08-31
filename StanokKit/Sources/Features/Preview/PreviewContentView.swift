import AppKit
import SwiftUI

struct PreviewContentView: View {

    private var resolvedCodeFamily: String {
        codeFamily.isEmpty ? terminalFamily : codeFamily
    }

    private var codeFont: NSFont {
        PreviewTypographyFonts.code(size: codeSize, family: resolvedCodeFamily)
    }

    private var gutter: CodeGutterRuler.Source? {
        guard case let .code(lines) = preview.content else { return nil }

        let digits = CGFloat(String(max(lines.count, 1)).count)

        return CodeGutterRuler.Source(
            changes: preview.changes,
            folds: folds,
            folded: folded,
            font: codeFont,
            width: digits * codeFont.maximumAdvancement.width + 4,
            toggle: toggle
        )
    }

    private var isCode: Bool {
        if case .code = preview.content { return true }

        return false
    }

    private var revision: String {
        [
            preview.url.path(percentEncoded: false),
            "\(markdownSize)", markdownFamily, "\(markdownSpacing)",
            "\(codeSize)", resolvedCodeFamily,
            folded.sorted().map(String.init).joined(separator: ",")
        ].joined(separator: "|")
    }

    @AppStorage(PreviewTypography.Keys.markdownFontSize)
    private var markdownSize = PreviewTypography.Defaults.markdownFontSize

    @AppStorage(PreviewTypography.Keys.markdownFontFamily)
    private var markdownFamily = PreviewTypography.Defaults.markdownFontFamily

    @AppStorage(PreviewTypography.Keys.markdownLineSpacing)
    private var markdownSpacing = PreviewTypography.Defaults.markdownLineSpacing

    @AppStorage(PreviewTypography.Keys.codeFontSize)
    private var codeSize = PreviewTypography.Defaults.codeFontSize

    @AppStorage(PreviewTypography.Keys.codeFontFamily)
    private var codeFamily = PreviewTypography.Defaults.codeFontFamily

    @State
    private var terminalFamily = ConfigFile.value(for: "font-family") ?? ""

    @State
    private var document = PreviewDocument.empty

    @State
    private var folds = CodeFoldMap.empty

    @State
    private var folded: Set<Int> = []

    @Environment(\.openURL)
    private var openURL

    var body: some View {
        PreviewTextView(
            document: document,
            mode: isCode ? .code : .reading,
            gutter: gutter,
            openLink: { openURL($0) }
        )
        .task(id: revision) { rebuild() }
        .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
            terminalFamily = ConfigFile.value(for: "font-family") ?? ""
        }
    }

    let preview: FilePreview
}

private extension PreviewContentView {

    func rebuild() {
        switch preview.content {
        case let .markdown(blocks):
            document = MarkdownDocumentBuilder.document(
                blocks: blocks,
                size: markdownSize,
                family: markdownFamily,
                lineSpacing: markdownSpacing,
                codeSize: codeSize,
                codeFamily: resolvedCodeFamily
            )

        case let .code(lines):
            if folds.isEmpty, folded.isEmpty {
                folds = CodeFoldMap(folds: CodeFolding.folds(for: lines))
            }

            document = CodeDocumentBuilder.document(
                lines: lines,
                folds: folds,
                folded: folded,
                font: codeFont
            )

        default:
            document = .empty
        }
    }

    func toggle(_ line: Int) {
        if folded.contains(line) {
            folded.remove(line)
        } else {
            folded.insert(line)
        }
    }
}
