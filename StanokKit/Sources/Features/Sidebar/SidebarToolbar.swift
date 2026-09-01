import SwiftUI

struct SidebarToolbar: View {

    @Binding
    var filterText: String

    @State
    private var monitor: AppResourceMonitor?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            filterField

            Spacer(minLength: 8)

            Text(ResourceUsageText.text(for: monitor?.usage))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .task {
            let started = AppResourceMonitor()
            started.start()
            monitor = started

            defer {
                started.stop()
                monitor = nil
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var filterField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            TextField("Поиск", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { CardStyle.flat.background(radius: WorkspaceLayout.cardRadius) }
        .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
    }
}
