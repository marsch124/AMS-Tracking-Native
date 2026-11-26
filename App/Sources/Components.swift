import SwiftUI

// Shared pieces: the Undo bar, the milestone celebration, cards, titles, week dots.

/// The one message at the bottom, inverted colours, with Undo (or another action) on the right.
struct ToastBar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if let t = store.toast {
            HStack(spacing: 14) {
                Text(t.text).font(.subheadline.weight(.semibold)).lineLimit(3)
                    .accessibilityIdentifier("toast-text")
                if let action = t.action {
                    Button(t.actionLabel) { store.hideToast(); action() }
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Color.dynamic(light: "#7ea4f7", dark: "#2c5fd8"))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("toast-action")
                }
            }
            .foregroundStyle(Ink.bg)
            .padding(.vertical, 12).padding(.horizontal, 18)
            .background(Capsule().fill(Ink.text))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(t.id)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("toast")
        }
    }
}

/// "7-day streak!" — a card that pops in for 2.1 s with a little confetti; never blocks a tap.
struct CelebrationOverlay: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var burst = false

    var body: some View {
        ZStack {
            if let c = store.celebration {
                if !reduceMotion { Confetti(colorHex: c.colorHex, burst: burst) }
                VStack(spacing: 6) {
                    TrackIcon(name: "flame", size: 52, color: Color(hex: c.colorHex), lineWidth: 1.9)
                    Text(c.title).font(.title3.weight(.heavy)).foregroundStyle(Ink.text)
                    Text(c.sub).font(.footnote.weight(.semibold)).foregroundStyle(Ink.dim)
                }
                .padding(.vertical, 26).padding(.horizontal, 34)
                .background(RoundedRectangle(cornerRadius: 24).fill(Ink.surface).shadow(color: .black.opacity(0.25), radius: 20, y: 10))
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .accessibilityIdentifier("celebration")
                .task(id: c.id) {
                    shown = false; burst = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true }
                    withAnimation(.easeOut(duration: 1.5)) { burst = true }
                    try? await Task.sleep(nanoseconds: 2_100_000_000)
                    withAnimation(.easeIn(duration: 0.3)) { shown = false }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if store.celebration?.id == c.id { store.celebration = nil }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Confetti: View {
    let colorHex: String
    let burst: Bool
    private var colors: [Color] {
        var hexes = [colorHex]
        for p in Palette.all where p != colorHex && hexes.count < 5 { hexes.append(p) }
        return hexes.map { Color(hex: $0) }
    }
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<26, id: \.self) { i in bit(i, geo.size) }
        }
    }

    /// One bit: where it flies to (angle and distance from the centre), how much it turns.
    private func bit(_ i: Int, _ size: CGSize) -> some View {
        let angle: Double = Double(i) / 26 * 2 * Double.pi + Double(i % 3) * 0.4
        let dist: Double = 90 + Double((i * 37) % 150)
        let turn: Double = burst ? Double((i * 53) % 540 - 270) : 0
        let dx: Double = burst ? cos(angle) * dist : 0
        let dy: Double = burst ? sin(angle) * dist - 40 : 0
        let x: Double = Double(size.width) / 2 + dx
        let y: Double = Double(size.height) * 0.45 + dy
        let corner: CGFloat = i % 3 == 0 ? 5 : 3
        return RoundedRectangle(cornerRadius: corner)
            .fill(colors[i % colors.count])
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(turn))
            .scaleEffect(burst ? 0.6 : 1)
            .position(x: x, y: y)
            .opacity(burst ? 0 : 1)
    }
}

// MARK: - Page pieces

/// The big page title ("Stats", a habit's name), 40 pt heavy like the web app, with an optional line under it.
struct PageTitle: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = Ink.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let icon { TrackIcon(name: icon, size: 34, color: iconColor) }
                Text(title).font(.largeTitle.weight(.heavy)).foregroundStyle(Ink.text)
                    .lineLimit(2).minimumScaleFactor(0.6)
            }
            if let subtitle {
                Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(Ink.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6).padding(.bottom, 12)
    }
}

/// A rounded card on the page (radius 22, surface, soft shadow) with an optional heading.
struct DetailCard<Content: View>: View {
    var title: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || trailing != nil {
                HStack {
                    if let title { Text(title).font(.title3.weight(.heavy)).foregroundStyle(Ink.text) }
                    Spacer()
                    if let trailing { trailing }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
    }
}

/// A full-width row button on a page ("Last week ›").
struct ListButton: View {
    let icon: String
    let title: String
    var id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TrackIcon(name: icon, size: 18, color: Ink.accent)
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Ink.text)
                Spacer()
                TrackIcon(name: "chevR", size: 15, color: Ink.dim)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 14).fill(Ink.surface).shadow(color: Ink.shadow, radius: 5, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The page background and width every screen uses: content up to 560 wide, centred.
struct Page<Content: View>: View {
    var id: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content }
                .frame(maxWidth: 560)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
        }
        .background(Ink.bg.ignoresSafeArea())
        .accessibilityIdentifier(id)
    }
}

// MARK: - Week dots (M T W T F S S of this week)

struct WeekDots: View {
    let habit: Habit
    var size: CGFloat = 16
    var gap: CGFloat = 5
    var onTap: ((String) -> Void)? = nil

    var body: some View {
        let monday = DayKey.weekStartKey(DayKey.today())
        HStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                let k = DayKey.add(monday, days: i)
                dot(k, i).onTapGesture { onTap?(k) }
                    .accessibilityIdentifier("weekdot-\(i)")
            }
        }
    }

    @ViewBuilder private func dot(_ k: String, _ i: Int) -> some View {
        let c = Color(hex: habit.color)
        let done = habit.isDone(k)
        let skip = !done && habit.skip.contains(k)
        ZStack {
            if done { Circle().fill(c) }
            else if skip { Circle().strokeBorder(c, lineWidth: 1.5) }
            else { Circle().fill(Ink.border) }
            Text(DayKey.letters[i])
                .font(.system(size: size * 0.56, weight: .bold))
                .foregroundStyle(done ? .white : skip ? c : Ink.dim)
        }
        .frame(width: size, height: size)
        .opacity(skip ? 0.75 : habit.isScheduled(k) ? 1 : 0.45)
    }
}

/// The flame-and-number streak mark.
struct Flame: View {
    var size: CGFloat = 18
    var color: Color
    var body: some View { TrackIcon(name: "flame", size: size, color: color) }
}
