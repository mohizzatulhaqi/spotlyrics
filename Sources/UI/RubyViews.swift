import SwiftUI

struct WrapLayout: Layout {
    var spacing: CGFloat = 0
    var rowSpacing: CGFloat = 6

    private func rows(_ subviews: Subviews, width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, s) in subviews.enumerated() {
            let w = s.sizeThatFits(.unspecified).width
            if x + w > width, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(i)
            x += w + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rs = rows(subviews, width: width)
        var maxW: CGFloat = 0
        var total: CGFloat = 0
        for r in rs {
            let w = r.reduce(0) { $0 + subviews[$1].sizeThatFits(.unspecified).width } + spacing * CGFloat(max(0, r.count - 1))
            let h = r.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            maxW = max(maxW, w)
            total += h
        }
        total += rowSpacing * CGFloat(max(0, rs.count - 1))
        return CGSize(width: proposal.width ?? maxW, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rs = rows(subviews, width: bounds.width)
        var y = bounds.minY
        for r in rs {
            let w = r.reduce(0) { $0 + subviews[$1].sizeThatFits(.unspecified).width } + spacing * CGFloat(max(0, r.count - 1))
            let h = r.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX + (bounds.width - w) / 2
            for i in r {
                let sz = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
                x += sz.width + spacing
            }
            y += h + rowSpacing
        }
    }
}

struct RubyLine: View {
    let tokens: [RubyToken]
    var size: CGFloat = 28
    var color: Color = .white

    var body: some View {
        WrapLayout(spacing: 0, rowSpacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, t in
                VStack(spacing: 0) {
                    Text(t.reading ?? " ")
                        .font(.system(size: max(9, size * 0.42), weight: .semibold))
                        .foregroundStyle(color.opacity(0.85))
                        .lineLimit(1)
                    Text(t.base)
                        .font(.system(size: size, weight: .heavy))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
                .fixedSize()
            }
        }
    }
}
