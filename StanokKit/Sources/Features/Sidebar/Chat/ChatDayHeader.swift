import SwiftUI

struct ChatDayHeader: View {

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    let title: String
}
