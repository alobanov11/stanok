import SwiftUI

struct TerminalStrip: View {

    private enum Metric {

        static let card = CGSize(width: 208, height: 128)
        static let radius: CGFloat = 10
        static let text: CGFloat = 4
    }

    var body: some View {
        content
            .frame(
                width: isVertical ? nil : Metric.card.width + 24,
                height: isVertical ? Metric.card.height + 24 : nil
            )
    }

    @ViewBuilder
    private var content: some View {
        if isVertical {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { cards }
                    .padding(.horizontal, 12)
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) { cards }
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        ForEach(sessions) { session in
            card(session)
        }
    }

    let sessions: [TerminalSession]
    let shown: Set<TerminalSession.ID>
    let selection: TerminalSession.ID?
    let isVertical: Bool
    let snapshots: TerminalSnapshots
    let onOpen: (TerminalSession) -> Void

    private func card(_ session: TerminalSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(session.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                if shown.contains(session.id) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }

            // Почему: это настоящий текст экрана терминала, а не картинка — миниатюра живая
            Text(snapshots.text(for: session.id) ?? "")
                .font(.system(size: Metric.text, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .padding(8)
        .frame(width: Metric.card.width, height: Metric.card.height)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: Metric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                .strokeBorder(
                    session.id == selection ? Color.accentColor.opacity(0.8) : .white.opacity(0.08),
                    lineWidth: 1
                )
        }
        .contentShape(.rect(cornerRadius: Metric.radius))
        .onTapGesture { onOpen(session) }
        .help(session.url.path(percentEncoded: false))
    }
}
