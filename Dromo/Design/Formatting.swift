import Foundation

// Display text for plan values. Kept apart from the model so the model stays plain data.

enum DurationText {
    /// 299 → "4:59"
    static func minutesSeconds(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    /// 1499 → "24:59", 6300 → "1:45:00"
    static func clock(_ seconds: Int) -> String {
        if seconds < 3600 {
            return minutesSeconds(seconds)
        }
        return "\(seconds / 3600):" + String(format: "%02d:%02d", seconds / 60 % 60, seconds % 60)
    }

    /// 2700 → "45 min", 3900 → "1 hr, 5 min" — localised.
    static func approximate(_ seconds: Int) -> String {
        let rounded = (seconds + 30) / 60 * 60
        return Duration.seconds(rounded).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

enum CountText {
    /// 1 → "1 week", 6 → "6 weeks"
    static func weeks(_ count: Int) -> String {
        if count == 1 {
            return "1 week"
        }
        return "\(count) weeks"
    }
}

enum DistanceText {
    /// 5000 → "5K", 21097 → "21.1 km": how races are named.
    static func race(_ meters: Int) -> String {
        if meters.isMultiple(of: 1000) {
            return "\(meters / 1000)K"
        }
        return kilometers(meters)
    }

    /// 7_350 → "7.4 km" — localised.
    static func kilometers(_ meters: Int) -> String {
        let oneDecimal = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        return Measurement(value: Double(meters) / 1000, unit: UnitLength.kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: oneDecimal))
    }
}

extension PaceRange {
    /// "5:10–5:20/km"
    var text: String { "\(shortText)/km" }

    /// "5:10–5:20", or "5:00" when both ends match.
    var shortText: String {
        if fastest == slowest {
            return DurationText.minutesSeconds(fastest)
        }
        return "\(DurationText.minutesSeconds(fastest))–\(DurationText.minutesSeconds(slowest))"
    }
}

extension PlanTime {
    /// "17:00"
    var text: String { String(format: "%02d:%02d", hour, minute) }
}

extension SegmentGoal {
    /// "15 sec", "1:30", "10 min", "600 m", "1 km", "Open"
    var text: String {
        switch self {
        case .time(let seconds):
            if seconds < 60 {
                return "\(seconds) sec"
            }
            if seconds < 5 * 60 || !seconds.isMultiple(of: 60) {
                return DurationText.minutesSeconds(seconds)
            }
            return "\(seconds / 60) min"
        case .distance(let meters):
            if meters < 1000 {
                return "\(meters) m"
            }
            if meters.isMultiple(of: 1000) {
                return "\(meters / 1000) km"
            }
            return String(format: "%.1f km", Double(meters) / 1000)
        case .open:
            return "Open"
        }
    }
}

extension SegmentBlock {
    /// "6 rounds", or what a single pass is: "Easy", "Tempo", "Race".
    var title: String {
        guard repeats == 1, let first = segments.first else { return "\(repeats) rounds" }
        if first.kind == .race {
            return "Race"
        }
        return first.name
    }
}

extension WorkoutSegment {
    /// "Warm-up", "Tempo", "KM 1"
    var name: String {
        if let label { return label }
        return switch kind {
        case .warmup: "Warm-up"
        case .easy: "Easy"
        case .work: "Work"
        case .stride: "Stride"
        case .recovery: "Recovery"
        case .cooldown: "Cool-down"
        case .race: "Race"
        }
    }

    /// How it's run, shown under the goal: "Easy", "Relaxed stride", "Held to pace".
    var effortText: String {
        if let label { return label }
        return switch kind {
        case .warmup, .easy, .cooldown: "Easy"
        case .recovery: "Easy jog"
        case .stride: "Relaxed stride"
        case .work: "Held to pace"
        case .race: "Race"
        }
    }
}

extension PlanDate {
    /// "Thu 1 Oct" (order follows the device locale)
    var shortText: String {
        startOfDay.formatted(Self.style.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "Thursday 1 October"
    var longText: String {
        startOfDay.formatted(Self.style.weekday(.wide).day().month(.wide))
    }

    /// "28 Sep"
    var dayMonthText: String {
        startOfDay.formatted(Self.style.day().month(.abbreviated))
    }

    /// "Today", "Tomorrow", or "Thu 1 Oct"
    func relativeText(today: PlanDate = .today) -> String {
        switch today.days(until: self) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: shortText
        }
    }

    private static var style: Date.FormatStyle {
        var style = Date.FormatStyle()
        style.timeZone = Calendar.plan.timeZone
        return style
    }
}

extension TrainingWeek {
    /// "28 Sep – 3 Oct"
    var dateRangeText: String? {
        guard let first = workouts.first?.date, let last = workouts.last?.date else { return nil }
        return "\(first.dayMonthText) – \(last.dayMonthText)"
    }
}
