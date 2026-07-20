// Components.swift — small reusable views shared across the detail panel sections.

import SwiftUI

struct BarView: View {
    let pct: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(4, geo.size.width * min(max(pct, 0), 100) / 100))
            }
        }
        .frame(height: 8)
    }
}

/// A centred small-caps caption sitting *on* a hairline separator (the "INTERFACE" / "ADDRESS"
/// look), used to title a section. An optional trailing control (e.g. a show-more toggle) is
/// overlaid at the right end of the same line. Shared by the Battery and Network popovers so their
/// section headers match.
struct SectionCaption<Trailing: View>: View {
    private let text: String
    private let trailing: Trailing

    init(_ text: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.text = text
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                hairline
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .fixedSize()
                hairline
            }
            HStack { Spacer(); trailing }
        }
    }

    private var hairline: some View {
        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.system(size: 12))
    }
}
