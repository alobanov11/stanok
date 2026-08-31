import SwiftUI

struct SectionHeader: View {

    var body: some View {
        Text(title)
            .font(Typography.heading)
            .tracking(Typography.headingTracking)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    let title: String
}
