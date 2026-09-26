import SwiftUI

/// The Sub-25 look, in one place. Every colour means one thing, everywhere:
///
/// - **Aegean blue** — the accent colour. The brand, and everything you can tap.
/// - **Sunset coral** (`quality`) — effort you're held to: Watch pace alerts.
/// - **Olive** (`easy`) — running by feel: easy runs, warm-ups, cool-downs, strides.
/// - **Laurel gold** (`race`) — race day.
///
/// The colours live in the asset catalog with dark and increased-contrast variants, all WCAG AA.
/// Blue dial and coral run: the same pair as the app icon.
enum Theme {
    /// The race header's Aegean night, matching the app icon.
    static let hero = LinearGradient(colors: [.heroTop, .heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Font {
    /// Numbers in SF Pro Rounded, as in Apple Fitness.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
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
        case .intervals, .steady: .quality
        case .race: .race
        }
    }
}

extension WorkoutSegment.Kind {
    /// This kind of running's colour in structure charts and step rows.
    var tint: Color {
        switch self {
        case .warmup, .cooldown: .easy.opacity(0.6)
        case .easy, .stride: .easy
        case .recovery: .gray.opacity(0.45)
        case .work: .quality
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
        case .completed: .green
        }
    }
}
