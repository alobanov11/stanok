import AppKit
import SwiftUI

struct ImagePreviewView: View {

    private enum Metric {

        static let cardHeight: CGFloat = 260
        static let radius: CGFloat = 10
        static let spacing: CGFloat = 12
    }

    var body: some View {
        content
            .padding(.top, topInset + Metric.spacing)
            .padding([.horizontal, .bottom], Metric.spacing)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if image.hasBoth {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Metric.spacing) { panes }

                VStack(spacing: Metric.spacing) { panes }
            }
        } else if let data = image.new {
            pane(data, title: "Файл")
        } else if let data = image.old {
            pane(data, title: "Было")
        } else {
            Text("Не удалось прочитать изображение")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var panes: some View {
        if let old = image.old { pane(old, title: "Было") }

        if let new = image.new { pane(new, title: "Стало") }
    }

    let image: ImagePreview

    var compact = false
    var topInset: CGFloat = 0

    private func pane(_ data: Data, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.tertiary)

            picture(data)

            Text(caption(for: data))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func picture(_ data: Data) -> some View {
        if let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: compact ? Metric.cardHeight : nil)
                .background(
                    .black.opacity(0.18),
                    in: .rect(cornerRadius: Metric.radius, style: .continuous)
                )
        } else {
            Text("Формат не поддерживается")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(
                    .black.opacity(0.18),
                    in: .rect(cornerRadius: Metric.radius, style: .continuous)
                )
        }
    }

    private func caption(for data: Data) -> String {
        let size = Int64(data.count).formatted(.byteCount(style: .file))
        guard let image = NSImage(data: data), let pixels = image.representations.first else {
            return size
        }

        return "\(pixels.pixelsWide)×\(pixels.pixelsHigh) · \(size)"
    }
}
