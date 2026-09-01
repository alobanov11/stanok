import AppKit
import SwiftUI

struct ReviewFileCard: View {

    private enum Metric {

        static let header: CGFloat = 30
        static let radius: CGFloat = 10
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: 12)
    }

    private var header: some View {
        HStack(spacing: 6) {
            chevron

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

            Spacer(minLength: 8)

            if let status = file.status {
                Text(status.letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Metric.header)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.smooth(duration: 0.18)) { isExpanded.toggle() }
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
        .background(.white.opacity(0.04), in: .rect(cornerRadius: Metric.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.16 : 0.08), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .task(id: revision) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let preview {
            switch preview.content {
            case .code, .markdown:
                PreviewContentView(preview: preview, scrolls: false)

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

    let file: ReviewFile

    @State
    var isExpanded: Bool

    @State
    private var preview: FilePreview?

    @State
    private var isHovering = false

    private var revision: String {
        isExpanded ? file.url.path(percentEncoded: false) : ""
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 40)
    }

    private func load() async {
        guard isExpanded, preview == nil, file.status != .deleted else { return }

        let loaded = await FilePreviewLoader.load(file.url)
        guard !Task.isCancelled else { return }

        preview = loaded
    }
}
