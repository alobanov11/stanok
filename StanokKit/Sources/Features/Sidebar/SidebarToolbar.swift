import SwiftUI

struct SidebarToolbar: View {

    @State
    private var monitor: AppResourceMonitor?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Spacer()

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

}
