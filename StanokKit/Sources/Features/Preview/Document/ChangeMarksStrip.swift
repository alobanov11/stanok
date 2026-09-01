import SwiftUI

struct ChangeMarksStrip: View {

    private enum Metric {

        static let width: CGFloat = 3
        static let inset: CGFloat = 3
        static let minimumMark: CGFloat = 2
    }

    private var marks: [(position: Double, weight: Double)] {
        guard !lines.isEmpty else { return [] }

        let span = Double(lines.count)
        var runs: [(start: Int, length: Int)] = []

        for (index, line) in lines.enumerated() where line >= 0 && changes.kinds[line + 1] != nil {
            if let last = runs.last, last.start + last.length == index {
                runs[runs.count - 1].length += 1
            } else {
                runs.append((index, 1))
            }
        }

        return runs.map { run in
            (Double(run.start) / span, Double(run.length) / span)
        }
    }

    var body: some View {
        let marks = marks

        return GeometryReader { proxy in
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                Capsule()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.85))
                    .frame(
                        width: Metric.width,
                        height: max(proxy.size.height * mark.weight, Metric.minimumMark)
                    )
                    .offset(y: proxy.size.height * mark.position)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.trailing, Metric.inset)
        .frame(width: Metric.width + Metric.inset * 2)
        .allowsHitTesting(false)
    }

    let lines: [Int]
    let changes: GitFileChanges
}
