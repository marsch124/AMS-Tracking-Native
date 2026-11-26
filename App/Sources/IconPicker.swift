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

