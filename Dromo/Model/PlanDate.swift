import Foundation

/// A calendar day, in the phone's time zone. Stored as components so it never shifts across time zones.
nonisolated struct PlanDate: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    static func < (lhs: PlanDate, rhs: PlanDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension PlanDate {
    init(_ year: Int, _ month: Int, _ day: Int) {
        self.init(year: year, month: month, day: day)
    }

    init(_ date: Date) {
        let parts = Calendar.plan.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    static var today: PlanDate { PlanDate(.now) }

    /// Midnight at the start of this day, local time.
    var startOfDay: Date {
        Calendar.plan.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func adding(days: Int) -> PlanDate {
        PlanDate(Calendar.plan.date(byAdding: .day, value: days, to: startOfDay)!)
    }

    /// Whole days from this date to `other`; negative when `other` is earlier.
    func days(until other: PlanDate) -> Int {
        Calendar.plan.dateComponents([.day], from: startOfDay, to: other.startOfDay).day!
    }
}

/// A time of day, only used where it matters (the race start).
nonisolated struct PlanTime: Codable, Hashable {
    var hour: Int
    var minute: Int
}

extension Calendar {
    /// Gregorian calendar in the phone's time zone, following it as it changes; every plan date is interpreted in it.
    static let plan: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}
