import SwiftUI

/// Dromo's Floodlight look: the race starts at 17:00 in November and finishes after sunset, under the lights.
/// Plain iOS screens with neon used sparingly, and every colour means one thing, everywhere:
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
    /// The race header: the night sky of the app icon. The same in both appearances.
    static var hero: some View {
        LinearGradient(colors: [.heroTop, .heroBottom], startPoint: .top, endPoint: .bottom)
    }

    /// `done` as a fill under the system's white labels, such as swipe actions: its Light Mode value in either appearance.
    static var doneAction: Color {
        var light = EnvironmentValues()
        light.colorScheme = .light
        return Color(Color.done.resolve(in: light))
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
