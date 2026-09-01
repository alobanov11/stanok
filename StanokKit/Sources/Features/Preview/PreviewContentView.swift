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
            "\(codeSize)", resolvedCodeFamily
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
    private var rebuildTask: Task<Void, Never>?

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
            fileKey: preview.url.path(percentEncoded: false),
            mode: isCode ? .code : .reading,
            gutter: gutter,
            topInset: topInset,
            openLink: { openURL($0) }
        )
        .task(id: revision) { await rebuild() }
        .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
            terminalFamily = ConfigFile.value(for: "font-family") ?? ""
        }
    }

    let preview: FilePreview

    var topInset: CGFloat = 0
}

private extension PreviewContentView {

    var documentRevision: String {
        [
            revision,
            folded.sorted().map(String.init).joined(separator: ","),
            expanded.sorted().map(String.init).joined(separator: ",")
        ].joined(separator: "|")
    }

    func rebuild() async {
        let file = fileRevision
        if builtFor != file {
            builtFor = file
            folds = .empty
            folded = []
            expanded = []
            document = .empty
        }

        let wanted = documentRevision
        let built = await build(revision: wanted)

        guard !Task.isCancelled, builtFor == file, wanted == documentRevision else { return }

        folds = built?.folds ?? .empty
        document = built?.document ?? .empty
    }

    func build(revision: String) async -> (document: PreviewDocument, folds: CodeFoldMap)? {
        switch preview.content {
        case let .markdown(blocks):
            let size = markdownSize
            let family = markdownFamily
            let spacing = markdownSpacing
            let codeSize = codeSize
            let codeFamily = resolvedCodeFamily

            let document = await Task.detached(priority: .userInitiated) {
                MarkdownDocumentBuilder.document(
                    blocks: blocks,
                    size: size,
                    family: family,
                    lineSpacing: spacing,
                    codeSize: codeSize,
                    codeFamily: codeFamily,
                    revision: revision
                )
            }.value

            return (document, .empty)

        case let .code(lines):
            let known = folds
            let folded = folded
            let expanded = expanded
            let changes = preview.changes
            let size = codeSize
            let family = resolvedCodeFamily

            return await Task.detached(priority: .userInitiated) {
                let folds = known.isEmpty
                    ? CodeFoldMap(folds: CodeFolding.folds(for: lines))
                    : known

                let document = CodeDocumentBuilder.document(
                    lines: lines,
                    folds: folds,
                    folded: folded,
                    changes: changes,
                    expanded: expanded,
                    font: PreviewTypographyFonts.code(size: size, family: family),
                    revision: revision
                )

                return (document, folds)
            }.value

        default:
            return nil
        }
    }

    func fold(_ line: Int) {
        if folded.contains(line) {
            folded.remove(line)
        } else {
            folded.insert(line)
        }

        restart()
    }

    func showChange(_ line: Int) {
        if expanded.contains(line) {
            expanded.remove(line)
        } else {
            expanded.insert(line)
        }

        restart()
    }

    func restart() {
        rebuildTask?.cancel()
        rebuildTask = Task { await rebuild() }
    }
}
