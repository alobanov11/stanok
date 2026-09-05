import AppKit
import SwiftUI

struct ReviewFileCard: View {

    private enum Metric {

        static let header: CGFloat = 30
        static let radius: CGFloat = 10
        static let notice: CGFloat = 40
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)

            Image(nsImage: FileIcons.icon(for: file.url, isDirectory: false))
                .resizable()
                .frame(width: 13, height: 13)

            Text(file.name)
                .font(Typography.row)
                .lineLimit(1)

            Text(file.path)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            if isExpanded, preview?.isTruncated == true {
                Text("первые 5000 строк")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if file.isReadable {
                Button { onOpen(file.url) } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Открыть файл целиком")
            }

            if let status = file.status {
                Text(status.letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Metric.header)
        // Почему: шапка лежит над текстом карточки, без подложки сквозь неё видно гаттер
        .background(.black.opacity(0.22))
        .contentShape(.rect)
        .onTapGesture { toggle() }
    }

    @ViewBuilder
    private var content: some View {
        if !file.isReadable {
            notice("файл удалён")
        } else if let preview {
            switch preview.content {
            case .code, .markdown:
                PreviewContentView(preview: preview, onlyChanges: true, scrolls: false)

            case let .image(image):
                ImagePreviewView(image: image, compact: true)

            case .tooLarge:
                notice("файл больше 2 МБ")

            case .unreadable:
                notice("двоичный файл")

            case let .failed(reason):
                notice(reason)
            }
        } else {
            notice("Загружаю")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                Divider().opacity(0.4)

                content
            }
        }
        .background(
            .white.opacity(0.04),
            in: .rect(cornerRadius: Metric.radius, style: .continuous)
        )
        .clipShape(.rect(cornerRadius: Metric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.16 : 0.08), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .onChange(of: isExpanded) { _, isOpen in
            // Почему: свёрнутая карточка не должна держать документ целого файла
            if !isOpen { preview = nil }
        }
        .task(id: file.id + "|\(file.status?.letter ?? "-")|\(isExpanded)|\(revision)") {
            await load()
        }
    }

    let file: ReviewFile
    let revision: String
    let cache: PreviewCache
    let onOpen: (URL) -> Void

    @Binding
    var isExpanded: Bool

    @State
    private var preview: FilePreview?

    @State
    private var isHovering = false

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: Metric.notice)
    }

    // Почему: анимировать высоту документа в тысячи строк — это буря раскладок при прокрутке
    private func toggle() {
        isExpanded.toggle()
    }

    nonisolated static func stamp(of url: URL) -> String {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: keys)
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0

        return "\(values?.fileSize ?? 0)|\(modified)"
    }

    private func load() async {
        guard isExpanded, file.isReadable else { return }

        // Почему: содержимое коммита неизменно, ключ не должен зависеть от рабочей копии
        let key: String
        if case .commit = file.source {
            key = file.id
        } else {
            let url = file.url
            let stamp = await Task.detached(priority: .userInitiated) { Self.stamp(of: url) }.value
            guard !Task.isCancelled else { return }

            key = [file.id, file.status?.letter ?? "-", stamp, revision].joined(separator: "|")
        }

        if let cached = cache.preview(for: key) {
            preview = cached
            return
        }

        let loaded = if case let .commit(sha) = file.source {
            await FilePreviewLoader.load(
                file.url,
                in: file.root,
                path: file.path,
                sha: sha,
                rendering: .plain
            )
        } else {
            await FilePreviewLoader.load(
                file.url,
                source: file.source,
                rendering: .plain,
                root: file.root
            )
        }
        guard !Task.isCancelled else { return }

        cache.store(loaded, for: key)
        preview = loaded
    }
}
