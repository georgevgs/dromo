import SwiftUI

/// Dromo's Golden Hour look: the race starts at 17:00 in November, as the sun sets over Athens.
/// Every colour means one thing, everywhere:
///
/// - **Dusk violet** — the accent colour. Everything you can tap.
/// - **Sunset** (`effort`; `effortInk` for text) — effort you're held to: Watch pace alerts.
/// - **Sea glass** (`easy`, `easyMuted`) — running by feel: easy runs, strides, warm-ups, cool-downs.
/// - **Gold** (`race`) — race day.
///
/// Colours live in the asset catalog with dark and increased-contrast variants, all WCAG AA.
/// The full system is Dromo Design, in Claude Design.
enum Theme {
    /// The race header: a dusk sky with the sun setting in its corner, like the app icon.
    static var hero: some View {
        LinearGradient(colors: [.heroTop, .heroBottom], startPoint: .top, endPoint: .bottom)
            .overlay {
                RadialGradient(colors: [.heroGlow.opacity(0.7), .clear], center: .topTrailing, startRadius: 0, endRadius: 280)
            }
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

    /// The symbol's colour on its tile: white, except dark ink on gold.
    var symbolColor: Color {
        self == .race ? .onRace : .white
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
