import SwiftUI

/// Dromo's Floodlight look: the race starts at 17:00 in November and finishes after sunset, under the lights.
/// A night-black ground, neon that glows through frosted glass, and every colour means one thing, everywhere:
///
/// - **Volt** (`accentFill` for fills; the accent colour for text and icons) — everything you can tap, and today.
/// - **Heat** (`effort`; `effortInk` for text) — effort you're held to: Watch pace alerts.
/// - **Ice** (`easy`, `easyMuted`) — running by feel: easy runs, strides, warm-ups, cool-downs.
/// - **Ultraviolet** (`race`) — race day.
/// - **Mint** (`done`) — finished.
///
/// Colours live in the asset catalog with dark and increased-contrast variants, all WCAG AA.
/// The full system is Dromo Design, in Claude Design.
enum Theme {
    /// The race header: the night sky, lit by heat and ice glows. The same in both appearances.
    static var hero: some View {
        LinearGradient(colors: [.heroTop, .heroBottom], startPoint: .top, endPoint: .bottom)
            .overlay {
                RadialGradient(colors: [Color.effort.opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            }
            .overlay {
                RadialGradient(colors: [Color.easy.opacity(0.4), .clear], center: .bottomLeading, startRadius: 0, endRadius: 240)
            }
            .environment(\.colorScheme, .dark)
    }

    /// Frosted glass for list rows, so the backdrop's glow shows through.
    static var glass: some View {
        Rectangle().fill(.thinMaterial)
    }

    /// Frosted glass with a glow of `tint` in its leading corner: the Up Next card.
    static func glass(glowing tint: Color) -> some View {
        glass.overlay {
            RadialGradient(colors: [tint.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
        }
    }

    /// Screen titles in the display face, scaled with Dynamic Type. Call once at launch.
    static func styleNavigationTitles() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 34, weight: .heavy, width: .expanded))]
        bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .bold, width: .expanded))]
    }

    /// `done` as a fill under the system's white labels, such as swipe actions: its Light Mode value in either appearance.
    static var doneAction: Color {
        var light = EnvironmentValues()
        light.colorScheme = .light
        return Color(Color.done.resolve(in: light))
    }
}

/// The ground behind every screen: night (or daylight) with soft neon glows that the glass rows frost over.
/// `glow` lights the top of the screen; a session screen passes its type's colour.
struct Backdrop: View {
    var glow: Color = .effort
    var secondGlow: Color = .easy

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strength = colorScheme == .dark ? 0.42 : 0.28
        Color.surface
            .overlay {
                RadialGradient(colors: [glow.opacity(strength), .clear], center: UnitPoint(x: 0.9, y: 0), startRadius: 0, endRadius: 460)
            }
            .overlay {
                RadialGradient(colors: [secondGlow.opacity(strength * 0.8), .clear], center: UnitPoint(x: 0, y: 0.35), startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension View {
    /// A list or form on the Floodlight backdrop. Give its sections `Theme.glass` row backgrounds.
    func floodlight(glow: Color = .effort, secondGlow: Color = .easy) -> some View {
        scrollContentBackground(.hidden)
            .background { Backdrop(glow: glow, secondGlow: secondGlow) }
    }
}

extension Font {
    /// SF Pro Expanded, for the numbers and titles that carry the brand.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, weight: weight).width(.expanded)
    }
}

extension SessionType {
    var symbol: String {
        switch self {
        case .easy: "figure.run"
        case .strides: "hare.fill"
        case .intervals: "stopwatch.fill"
        case .steady: "gauge.with.needle.fill"
        case .race: "medal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .easy, .strides: .easy
        case .intervals, .steady: .effort
        case .race: .race
        }
    }
}

extension WorkoutSegment.Kind {
    /// This kind of running's colour in structure charts and step rows.
    var tint: Color {
        switch self {
        case .warmup, .cooldown: .easyMuted
        case .easy, .stride: .easy
        case .recovery: .recovery
        case .work: .effort
        case .race: .race
        }
    }
}

extension WorkoutStatus {
    var title: String {
        switch self {
        case .upcoming: "Not on Watch yet"
        case .onWatch: "On Apple Watch"
        case .completed: "Done"
        case .missed: "Missed"
        }
    }

    var symbol: String? {
        switch self {
        case .upcoming: nil
        case .onWatch: "applewatch"
        case .completed: "checkmark.circle.fill"
        case .missed: "minus.circle"
        }
    }

    var tint: Color {
        switch self {
        case .upcoming, .missed: .secondary
        case .onWatch: .accentColor
        case .completed: .done
        }
    }
}

/// A plan section's title, such as "Up Next" or "Week 1", in the display face.
struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.display(.title3, weight: .heavy))
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}
