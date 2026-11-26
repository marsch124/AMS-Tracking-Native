import SwiftUI

/// Search + the 40 habit icons. A search matches the icon's name or its English / German words.
enum IconSearch {
    static func filter(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return TrackIcons.habitNames }
        return TrackIcons.habitNames.filter { $0.lowercased().contains(q) || (TrackIcons.keywords[$0] ?? "").lowercased().contains(q) }
    }
}

struct IconPicker: View {
    @Binding var selection: String
    @Binding var search: String

    var body: some View {
        let shown = IconSearch.filter(search)
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search icons… (e.g. coffee, schlafen)", text: $search)
                .textFieldStyle(.plain)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("f-icon-search")
            if shown.isEmpty {
                Text("No icons match — clear the search to see all.").font(.footnote).foregroundStyle(Ink.dim)
                    .accessibilityIdentifier("icon-none")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 48), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(shown, id: \.self) { name in
                        Button { selection = name } label: {
                            TrackIcon(name: name, size: 25, color: Ink.text)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface).shadow(color: Ink.shadow, radius: 3, y: 1))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection == name ? Ink.accent : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                        .accessibilityIdentifier("icon-\(name)")
                    }
                }
            }
        }
    }
}

/// Chips that wrap onto new lines (the "Serves" pills).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 300, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(bounds.width, subviews)
        for (i, p) in r.points.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified) }
    }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var pts: [CGPoint] = []; var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y)); x += sz.width + spacing; rowH = max(rowH, sz.height); maxW = max(maxW, x - spacing)
        }
        return (pts, CGSize(width: maxW, height: y + rowH))
    }
}
