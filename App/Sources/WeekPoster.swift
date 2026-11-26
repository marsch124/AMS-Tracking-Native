import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// The week poster (web `renderWeekPoster` 2365): 1080 x 1350, always the light palette, drawn from the same
// WeekReport the screen shows. Rendered with ImageRenderer into a PNG the share sheet can send.

struct WeekPosterView: View {
    let report: WeekReport

    private let bg = Color(hex: "#f2f4f8"), card = Color.white, text = Color(hex: "#16181d")
    private let dim = Color(hex: "#7a7f8a"), empty = Color(hex: "#e8ebf1")
    private let up = Color(hex: "#2fa96d"), down = Color(hex: "#d9463e")

    var body: some View {
        let rows = report.rows
        let top: CGFloat = 300, bottom: CGFloat = 1190
        let pitch = min(250, (bottom - top) / CGFloat(max(rows.count, 1)))
        ZStack(alignment: .topLeading) {
            bg
            RoundedRectangle(cornerRadius: 44).fill(card).frame(width: 980, height: 1250).offset(x: 50, y: 50)
            Text("My week").font(.system(size: 62, weight: .heavy)).foregroundStyle(text).offset(x: 106, y: 98)
            Text(Self.range(report)).font(.system(size: 34, weight: .bold)).foregroundStyle(dim).offset(x: 106, y: 174)
            VStack(alignment: .trailing, spacing: 0) {
                Text(report.headFigure).font(.system(size: 70, weight: .heavy)).foregroundStyle(report.allMet ? up : text)
                Text(report.headLabel).font(.system(size: 27, weight: .semibold)).foregroundStyle(dim)
            }
            .frame(width: 400, alignment: .trailing).offset(x: 574, y: 104)
            Rectangle().fill(empty).frame(width: 868, height: 3).offset(x: 106, y: 252)

            VStack(spacing: 0) {
                ForEach(rows) { r in block(r, pitch: pitch) }
            }
            .frame(width: 868, height: bottom - top).offset(x: 106, y: top)

            Text("AMS Tracking · my week in review").font(.system(size: 26, weight: .semibold)).foregroundStyle(dim)
                .frame(width: 1080).multilineTextAlignment(.center).offset(x: 0, y: 1234)
        }
        .frame(width: 1080, height: 1350, alignment: .topLeading)
        .clipped()
    }

    private func block(_ r: WeekRow, pitch: CGFloat) -> some View {
        let c = Color(hex: r.habit.color)
        let cell: CGFloat = pitch >= 200 ? 78 : pitch >= 150 ? 62 : 54
        let gap: CGFloat = pitch >= 200 ? 16 : 14
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 20) {
                TrackIcon(name: r.habit.icon, size: 52, color: c, lineWidth: 1.9)
                Text(r.habit.name).font(.system(size: 42, weight: .heavy)).foregroundStyle(text)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 10)
                Text(r.mid).font(.system(size: 40, weight: .heavy)).foregroundStyle(r.met == true ? up : text)
                    .lineLimit(1).fixedSize()
                if !r.delta.isEmpty {
                    Text(Self.deltaText(r)).font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(r.trend == .up ? up : r.trend == .down ? down : dim)
                        .lineLimit(1).fixedSize()
                }
            }
            HStack(spacing: gap) {
                ForEach(0..<7, id: \.self) { d in
                    let st = r.days[d]
                    ZStack {
                        switch st {
                        case .done: RoundedRectangle(cornerRadius: 16).fill(c)
                        case .skip: RoundedRectangle(cornerRadius: 14).strokeBorder(c, style: StrokeStyle(lineWidth: 3.5, dash: [7, 5])).padding(2)
                        case .off: RoundedRectangle(cornerRadius: 16).fill(empty).opacity(0.5)
                        case .empty: RoundedRectangle(cornerRadius: 16).fill(empty)
                        }
                        Text(DayKey.letters[d]).font(.system(size: (cell * 0.42).rounded(), weight: .heavy))
                            .foregroundStyle(st == .done ? Color.white : dim)
                    }
                    .frame(width: cell, height: cell)
                }
            }
            .padding(.leading, 72)
        }
        .frame(maxWidth: .infinity, minHeight: pitch, maxHeight: pitch, alignment: .center)
    }

    static func range(_ r: WeekReport) -> String { LastWeekScreen.range(r.ws) }

    /// "+2 days", "–1 week": the streak change with its unit; a fasting row has no unit.
    static func deltaText(_ r: WeekRow) -> String {
        guard let u = r.unit, let v = r.deltaValue else { return r.delta }
        return r.delta + " " + u + (abs(v) != 1 ? "s" : "")
    }
}

enum WeekPoster {
    /// Draws the poster into a PNG in the temporary folder and returns where it is (nil when drawing fails).
    @MainActor
    static func render(_ report: WeekReport) -> URL? {
        let renderer = ImageRenderer(content: WeekPosterView(report: report).environment(\.colorScheme, .light))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        guard let image = renderer.cgImage else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ams-tracking-week-\(report.ws).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? url : nil
    }
}
