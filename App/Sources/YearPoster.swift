import SwiftUI

// The year poster (web 6.5): a 1080 x 1350 picture of one habit's year, always in the light palette,
// drawn as a SwiftUI view and rendered to a PNG with ImageRenderer.

struct PosterStat: Equatable { var value: String; var label: String }

extension Habit {
    /// The big numbers of the poster and of a year card (web: current year weekly / other, past year).
    func posterStats(_ year: Int, today: String) -> [PosterStat] {
        let cur = Int(today.prefix(4)) ?? year
        if year == cur {
            if type == .weekly {
                let w = weeklyStats(today: today)
                return [PosterStat(value: "\(weeklyStreak(today: today))", label: "week streak"),
                        PosterStat(value: "\(w.best)", label: "best streak"),
                        PosterStat(value: "\(w.weeksMet)/\(w.weeksTotal)", label: "weeks met")]
            }
            return [PosterStat(value: "\(currentStreak(today: today))", label: "day streak"),
                    PosterStat(value: "\(longestStreak(today: today))", label: "longest streak"),
                    PosterStat(value: "\(completion(today: today).pct)%", label: "completion")]
        }
        let s = yearSummary(year, today: today)
        return [PosterStat(value: "\(s.done)", label: "days done"), PosterStat(value: "\(s.scheduled)", label: "days scheduled")]
    }

    /// Every day of a year, in order, as day keys.
    static func yearKeys(_ year: Int) -> [[String]] {
        (1...12).map { m in
            guard let first = DayKey.calendar.date(from: DateComponents(year: year, month: m, day: 1)),
                  let n = DayKey.calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
            return (0..<n).map { DayKey.key(DayKey.add(first, days: $0)) }
        }
    }
}

struct YearPosterView: View {
    let habit: Habit
    let year: Int
    let today: String

    private let bg = Color(hex: "#f2f4f8"), ink = Color(hex: "#16181d"), dim = Color(hex: "#7a7f8a"), empty = Color(hex: "#e8ebf1")

    var body: some View {
        let c = Color(hex: habit.color)
        let months = Habit.yearKeys(year)
        let stats = habit.posterStats(year, today: today)
        ZStack(alignment: .topLeading) {
            bg
            RoundedRectangle(cornerRadius: 44).fill(.white).frame(width: 980, height: 1250).offset(x: 50, y: 50)
            TrackIcon(name: habit.icon, size: 96, color: c, lineWidth: 1.9).offset(x: 106, y: 104)
            Text(habit.name).font(.system(size: 66, weight: .heavy)).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.45).frame(width: 760, alignment: .leading).offset(x: 228, y: 98)
            Text(String(year)).font(.system(size: 42, weight: .heavy)).foregroundStyle(dim).offset(x: 228, y: 178)
            ForEach(0..<12, id: \.self) { m in
                let y = 306 + CGFloat(m) * 46
                Text(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"][m])
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(dim).offset(x: 106, y: y - 2)
                ForEach(Array(months[m].enumerated()), id: \.offset) { d, k in
                    cell(k, c).offset(x: 150 + CGFloat(d) * 27.5, y: y)
                }
            }
            ForEach(Array(stats.enumerated()), id: \.offset) { i, s in
                let w = 980.0 / Double(stats.count)
                VStack(spacing: 2) {
                    Text(s.value).font(.system(size: 86, weight: .heavy)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.5)
                    Text(s.label).font(.system(size: 30, weight: .semibold)).foregroundStyle(dim)
                }
                .frame(width: w).offset(x: 50 + Double(i) * w, y: 960)
            }
            Text("AMS Tracking · \(String(year)), pixel by pixel").font(.system(size: 26, weight: .semibold)).foregroundStyle(dim)
                .frame(width: 1080).offset(y: 1218)
        }
        .frame(width: 1080, height: 1350, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private func cell(_ k: String, _ c: Color) -> some View {
        switch habit.pixel(k, today: today) {
        case .done: RoundedRectangle(cornerRadius: 6).fill(c).frame(width: 22, height: 22)
        case .skip:
            RoundedRectangle(cornerRadius: 6).strokeBorder(c, style: StrokeStyle(lineWidth: 2.4, dash: [4, 3]))
                .frame(width: 22, height: 22)
        case .empty: RoundedRectangle(cornerRadius: 6).fill(empty).frame(width: 22, height: 22)
        case .future: RoundedRectangle(cornerRadius: 6).fill(empty.opacity(0.45)).frame(width: 22, height: 22)
        }
    }
}

/// A rendered poster: the picture to look at and the PNG file to share.
struct PosterFile: Identifiable {
    let id = UUID()
    let url: URL
    let year: Int
    let name: String
    #if os(iOS)
    let image: UIImage
    #else
    let image: NSImage
    #endif
}

@MainActor
enum PosterMaker {
    static func slug(_ s: String) -> String {
        let t = s.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        let parts = t.split(separator: "-").map(String.init)
        return parts.isEmpty ? "habit" : parts.joined(separator: "-")
    }

    static func make(_ habit: Habit, year: Int, today: String) -> PosterFile? {
        let r = ImageRenderer(content: YearPosterView(habit: habit, year: year, today: today))
        r.scale = 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ams-tracking-\(slug(habit.name))-\(year).png")
        #if os(iOS)
        guard let img = r.uiImage, let data = img.pngData() else { return nil }
        #else
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        #endif
        do { try data.write(to: url) } catch { return nil }
        return PosterFile(url: url, year: year, name: habit.name, image: img)
    }
}

/// The sheet that shows the poster with a Share button.
struct PosterSheet: View {
    let poster: PosterFile
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            Image(uiImage: poster.image).resizable().scaledToFit()
            #else
            Image(nsImage: poster.image).resizable().scaledToFit()
            #endif
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Done").font(.body.weight(.semibold)).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.border, lineWidth: 1))
                }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityIdentifier("btn-poster-done")
                ShareLink(item: poster.url, preview: SharePreview("\(poster.name) \(poster.year)")) {
                    Text("Share poster").font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.accent))
                }
                .buttonStyle(.plain).accessibilityIdentifier("btn-poster-share")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
        .background(Ink.bg.ignoresSafeArea())
        .accessibilityIdentifier("sheet-poster")
    }
}
