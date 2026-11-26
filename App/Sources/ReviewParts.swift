import SwiftUI

// Small pieces the Stats, Last week, Last month and Aspirations screens share.

/// Title in the toolbar on iPad and Mac (the page has its own big title on the iPhone).
struct ReviewChrome: ViewModifier {
    let title: String
    @EnvironmentObject var nav: Nav
    func body(content: Content) -> some View {
        content
            .navigationTitle(nav.wide ? title : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

extension View {
    func reviewChrome(_ title: String) -> some View { modifier(ReviewChrome(title: title)) }
}

/// "THE WEEK IN WORDS" — a small uppercase heading with an optional hint under it.
struct SectionHeading: View {
    let title: String
    var hint: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.footnote.weight(.heavy)).tracking(0.7).foregroundStyle(Ink.dim)
            if let hint { Text(hint).font(.footnote).foregroundStyle(Ink.dim) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A plain card: surface, radius 16 (the web's note-card).
struct NoteCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
    }
}

/// The dashed box that says there is nothing to show yet, and why.
struct EmptyNote: View {
    let text: String
    var id: String = "empty-note"
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(Ink.dim)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.dim.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
            .accessibilityIdentifier(id)
    }
}

/// A bar chart of seven (or up to six) columns, one series in the chart ink, a label under each.
struct BarChartCard: View {
    let heading: String
    let values: [Int]
    let ceiling: Int
    let labels: [String]
    let caption: String
    var id: String = "chart"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading.uppercased()).font(.footnote.weight(.heavy)).tracking(0.7).foregroundStyle(Ink.dim)
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(values.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8).fill(Ink.border)
                            GeometryReader { g in
                                let f = min(1, Double(values[i]) / Double(max(ceiling, 1)))
                                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8)
                                    .fill(Ink.chart)
                                    .frame(height: g.size.height * f)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(height: 116)
                        Text(labels[i]).font(.caption.weight(.heavy)).foregroundStyle(Ink.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(labels[i]): \(values[i])")
                }
            }
            Text(caption).font(.footnote).foregroundStyle(Ink.dim)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }
}

/// The seven day marks of one habit's week: solid = done, dashed = skip day, faint = not asked for, grey = open.
struct WeekMarks: View {
    let row: WeekRow
    var body: some View {
        let c = Color(hex: row.habit.color)
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let m = row.days[i]
                ZStack {
                    switch m {
                    case .done: RoundedRectangle(cornerRadius: 9).fill(c)
                    case .skip: RoundedRectangle(cornerRadius: 9).strokeBorder(c, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    case .off: RoundedRectangle(cornerRadius: 9).fill(Ink.border).opacity(0.45)
                    case .empty: RoundedRectangle(cornerRadius: 9).fill(Ink.border)
                    }
                    Text(DayKey.letters[i]).font(.caption.weight(.heavy))
                        .foregroundStyle(m == .done ? .white : m == .skip ? c : Ink.dim)
                }
                .frame(maxWidth: 45).aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.days.enumerated().map { "\(DayKey.shortNames[$0.offset]) \(label($0.element))" }.joined(separator: ", "))
    }
    private func label(_ m: WeekRow.Mark) -> String {
        switch m { case .done: "done"; case .skip: "skip day"; case .off: "not scheduled"; case .empty: "open" }
    }
}

extension WeekRow.Trend {
    var color: Color { switch self { case .up: Ink.green; case .down: Ink.red; case .flat: Ink.dim } }
}

/// One habit's line in a review: icon, name, the figure next to the name, the change.
struct ReviewRowTop: View {
    let habit: Habit
    let mid: String
    var met = false
    var delta = ""
    var trend: WeekRow.Trend = .flat
    var flame = false
    var body: some View {
        HStack(spacing: 8) {
            TrackIcon(name: habit.icon, size: 18, color: Color(hex: habit.color))
            Text(habit.name).font(.subheadline.weight(.bold)).foregroundStyle(Ink.text).lineLimit(1)
            Text(mid).font(.subheadline.weight(.heavy)).foregroundStyle(met ? Ink.green : Ink.text).lineLimit(1)
            if !delta.isEmpty {
                HStack(spacing: 2) {
                    Text(delta).font(.footnote.weight(.heavy))
                    if flame { Flame(size: 13, color: trend.color) }
                }
                .foregroundStyle(trend.color)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Chips that wrap onto the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
