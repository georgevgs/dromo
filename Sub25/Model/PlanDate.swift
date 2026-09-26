import Foundation

/// A calendar day in the plan's time zone. Stored as components so it never shifts across time zones.
struct PlanDate: Codable, Hashable, Comparable {
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
        let parts = Calendar.athens.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    static var today: PlanDate { PlanDate(.now) }

    /// Midnight at the start of this day, Athens time.
    var startOfDay: Date {
        Calendar.athens.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func adding(days: Int) -> PlanDate {
        PlanDate(Calendar.athens.date(byAdding: .day, value: days, to: startOfDay)!)
    }

    /// Whole days from this date to `other`; negative when `other` is earlier.
    func days(until other: PlanDate) -> Int {
        Calendar.athens.dateComponents([.day], from: startOfDay, to: other.startOfDay).day!
    }
}

/// A time of day, only used where it matters (the race start).
struct PlanTime: Codable, Hashable {
    var hour: Int
    var minute: Int
}

extension TimeZone {
    static let athens = TimeZone(identifier: "Europe/Athens")!
}

extension Calendar {
    /// Gregorian calendar in Athens time; every plan date is interpreted in it.
    static let athens: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .athens
        return calendar
    }()
}
