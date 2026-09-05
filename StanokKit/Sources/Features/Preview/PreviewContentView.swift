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
            showChange: showChange,
            note: toggleNote,
            noteLine: noteLine
        )
    }

    private var contentLines: Int? {
        guard !scrolls, isCode, !document.lines.isEmpty else { return nil }

        return document.lines.count
    }

    private var isCode: Bool {
        if case .code = preview.content { return true }

        return false
    }

    private var fileRevision: String {
        [
            preview.url.path(percentEncoded: false),
            "\(preview.size)",
            "\(preview.modified?.timeIntervalSince1970 ?? 0)"
        ].joined(separator: "|")
    }

    private var revision: String {
        [
            fileRevision,
            "\(preview.changes.digest)",
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
    private var builtURL: URL?

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

    @Environment(\.previewNotes)
    private var notes

    @State
    private var noteLine: Int?

    @State
    private var noteRect = CGRect.zero

    var body: some View {
        PreviewTextView(
            document: document,
            fileKey: preview.url.path(percentEncoded: false),
            shape: shape,
            mode: isCode ? .code : .reading,
            gutter: gutter,
            topInset: topInset,
            openLink: { openURL($0) },
            scrolls: scrolls,
            contentLines: contentLines,
            noteLine: noteLine,
            onNoteFrame: { noteRect = $0 },
            onScroll: { noteLine = nil }
        )
        .overlay(alignment: .topLeading) { note }
        .overlay(alignment: .trailing) { marks.allowsHitTesting(false) }
        .task(id: revision) { await rebuild() }
        .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
            terminalFamily = ConfigFile.value(for: "font-family") ?? ""
        }
    }

    // Почему: правка отправляется сразу в терминал и нигде не остаётся — это разовая записка
    @ViewBuilder
    private var note: some View {
        if let noteLine, noteRect.height > 0 {
            PreviewNoteField(
                line: noteLine,
                onSend: { text in
                    notes.send(PreviewNote(url: preview.url, line: noteLine, text: text))
                    self.noteLine = nil
                },
                onCancel: { self.noteLine = nil }
            )
            .frame(height: PreviewTextView.noteHeight)
            .padding(.leading, noteRect.minX)
            .offset(y: noteRect.minY)
        }
    }

    @ViewBuilder
    private var marks: some View {
        if scrolls, isCode, !preview.changes.kinds.isEmpty {
            ChangeMarksStrip(lines: document.lines, changes: preview.changes)
                .padding(.top, topInset)
        }
    }

    let preview: FilePreview

    var onlyChanges = false
    var topInset: CGFloat = 0
    var scrolls = true
}

private extension PreviewContentView {

    var shape: String {
        folded.sorted().map(String.init).joined(separator: ",")
            + "|" + expanded.sorted().map(String.init).joined(separator: ",")
    }

    var documentRevision: String {
        [
            revision,
            folded.sorted().map(String.init).joined(separator: ","),
            expanded.sorted().map(String.init).joined(separator: ",")
        ].joined(separator: "|")
    }

    // Почему: повторный клик по номеру закрывает поле — это toggle, а не отдельная кнопка
    func toggleNote(_ line: Int) {
        noteRect = .zero

        noteLine = noteLine == line ? nil : line
    }

    func rebuild() async {
        let file = fileRevision
        if builtFor != file {
            builtFor = file
            folds = .empty
            folded = []
            expanded = []

            // Почему: тот же файл дочитывается со старым текстом, чужой — не мелькает вовсе
            if builtURL != preview.url {
                builtURL = preview.url
                document = .empty
            }
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
                    revision: revision,
                    onlyChanges: onlyChanges
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
