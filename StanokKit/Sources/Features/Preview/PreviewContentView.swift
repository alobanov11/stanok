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
            expanded: expanded,
            font: codeFont,
            width: digits * codeFont.maximumAdvancement.width + 4,
            fold: fold,
            showChange: showChange
        )
    }

    private var isCode: Bool {
        if case .code = preview.content { return true }

        return false
    }

    private var fileRevision: String {
        [
            preview.url.path(percentEncoded: false),
            "\(preview.size)",
            "\(preview.modified?.timeIntervalSince1970 ?? 0)",
            "\(preview.changes.kinds.count)",
            "\(preview.changes.removed.count)"
        ].joined(separator: "|")
    }

    private var revision: String {
        [
            fileRevision,
            "\(markdownSize)", markdownFamily, "\(markdownSpacing)",
            "\(codeSize)", resolvedCodeFamily,
            folded.sorted().map(String.init).joined(separator: ","),
            expanded.sorted().map(String.init).joined(separator: ",")
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
    private var builtFor = ""

    @State
    private var folds = CodeFoldMap.empty

    @State
    private var folded: Set<Int> = []

    @State
    private var expanded: Set<Int> = []

    @Environment(\.openURL)
    private var openURL

    var body: some View {
        PreviewTextView(
            document: document,
            mode: isCode ? .code : .reading,
            gutter: gutter,
            topInset: topInset,
            openLink: { openURL($0) }
        )
        .task(id: revision) { rebuild() }
        .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
            terminalFamily = ConfigFile.value(for: "font-family") ?? ""
        }
    }

    let preview: FilePreview

    var topInset: CGFloat = 0
}

private extension PreviewContentView {

    func rebuild() {
        if builtFor != fileRevision {
            builtFor = fileRevision
            folds = .empty
            folded = []
            expanded = []
        }

        switch preview.content {
        case let .markdown(blocks):
            document = MarkdownDocumentBuilder.document(
                blocks: blocks,
                size: markdownSize,
                family: markdownFamily,
                lineSpacing: markdownSpacing,
                codeSize: codeSize,
                codeFamily: resolvedCodeFamily,
                revision: revision
            )

        case let .code(lines):
            if folds.isEmpty {
                folds = CodeFoldMap(folds: CodeFolding.folds(for: lines))
            }

            document = CodeDocumentBuilder.document(
                lines: lines,
                folds: folds,
                folded: folded,
                removed: preview.changes.removed,
                expanded: expanded,
                font: codeFont,
                revision: revision
            )

        default:
            document = .empty
        }
    }

    func fold(_ line: Int) {
        if folded.contains(line) {
            folded.remove(line)
        } else {
            folded.insert(line)
        }
    }

    func showChange(_ line: Int) {
        if expanded.contains(line) {
            expanded.remove(line)
        } else {
            expanded.insert(line)
        }
    }
}
