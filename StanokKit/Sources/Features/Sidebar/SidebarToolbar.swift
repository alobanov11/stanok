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
        }
    }

    private var filterField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            TextField("Фильтр чатов", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background { CardStyle.flat.background(radius: 8) }
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
    }

}
