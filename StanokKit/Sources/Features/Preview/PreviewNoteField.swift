import SwiftUI

struct PreviewNoteField: View {

    var body: some View {
        HStack(spacing: 8) {
            TextField("Правка к строке \(line) — Enter отправит в терминал", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(text.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Почему: строка правки живёт внутри кода, поэтому подложка такая же, как у выделения
        .background(.white.opacity(0.07))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 2)
        }
        .task { isFocused = true }
    }

    let line: Int
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State
    private var text = ""

    @FocusState
    private var isFocused: Bool

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onSend(trimmed)
    }

    private func cancel() {
        onCancel()
    }
}
