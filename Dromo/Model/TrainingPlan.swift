import Foundation

// The training plan as plain values, independent of WorkoutKit. The app owns the whole plan;
// WorkoutKit only ever receives converted copies of single workouts (see `WorkoutKitConverter`).
// Nonisolated, as plain values should be, so a plan can be written off the main thread (see `SharedPlan`).

// MARK: - Plan

nonisolated struct TrainingPlan: Codable, Hashable {
    var title: String
    /// What the plan builds up to, if anything: a base-building block has no race.
    var race: Race?
    var weeks: [TrainingWeek]
}

nonisolated struct Race: Codable, Hashable {
    var name: String
    var date: PlanDate
    var distanceMeters: Int
    var goalTimeSeconds: Int?
}

extension TrainingPlan {
    /// Every session in date order.
    var workouts: [PlannedWorkout] {
        weeks.flatMap(\.workouts)
    }

    var raceWorkout: PlannedWorkout? {
        race.flatMap { race in workouts.first { $0.date == race.date } }
    }
}

extension Race {
    /// Average pace the goal needs, rounded down to whole seconds: 24:59 over 5 km → 4:59/km.
    var goalPaceSecondsPerKm: Int? {
        goalTimeSeconds.map { $0 * 1000 / distanceMeters }
    }
}

nonisolated extension TrainingPlan {
    private enum CodingKeys: String, CodingKey {
        case title, race, weeks
    }

    /// Plans saved before the race became optional kept it in four fields of their own.
    private enum LegacyKeys: String, CodingKey {
        case raceName, raceDate, raceDistanceMeters, goalTimeSeconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        weeks = try container.decode([TrainingWeek].self, forKey: .weeks)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        if legacy.contains(.raceName) {
            race = Race(
                name: try legacy.decode(String.self, forKey: .raceName),
                date: try legacy.decode(PlanDate.self, forKey: .raceDate),
                distanceMeters: try legacy.decode(Int.self, forKey: .raceDistanceMeters),
                goalTimeSeconds: try legacy.decodeIfPresent(Int.self, forKey: .goalTimeSeconds)
            )
        } else {
            race = try container.decodeIfPresent(Race.self, forKey: .race)
        }
    }
}

nonisolated struct TrainingWeek: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var workouts: [PlannedWorkout]
}

// MARK: - Workout

nonisolated struct PlannedWorkout: Codable, Hashable, Identifiable {
    /// Also the WorkoutKit plan ID — how a scheduled workout is matched back to the plan.
    var id: UUID
    var date: PlanDate
    /// Only set when the start time matters (race day).
    var startTime: PlanTime?
    var title: String
    var notes: String?
    /// A benchmark session whose result should inform later targets.
    var isCheckpoint = false
    var warmup: WorkoutSegment?
    var blocks: [SegmentBlock] = []
    var cooldown: WorkoutSegment?
}

extension PlannedWorkout {
    /// Each distinct segment once, in order.
    var segments: [WorkoutSegment] {
        [warmup].compactMap(\.self) + blocks.flatMap(\.segments) + [cooldown].compactMap(\.self)
    }

    /// Everything the runner actually does, in order, with repeats expanded.
    var timeline: [WorkoutSegment] {
        [warmup].compactMap(\.self)
            + blocks.flatMap { block in Array(repeating: block.segments, count: block.repeats).flatMap(\.self) }
            + [cooldown].compactMap(\.self)
    }
}

/// Segments run `repeats` times in a row, e.g. 6 × (1:30 work + 2:00 recovery).
nonisolated struct SegmentBlock: Codable, Hashable, Identifiable {
    var id = UUID()
    var repeats = 1
    var segments: [WorkoutSegment]
}

nonisolated struct WorkoutSegment: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case warmup, easy, work, stride, recovery, cooldown, race

        /// The one place that decides which running is pace-enforced on the Watch.
        /// Easy running, strides, recoveries and the race itself are run by feel.
        var enforcesPace: Bool { self == .work }
    }

    var id = UUID()
    var kind: Kind
    var goal: SegmentGoal
    /// A Watch pace alert when `kind.enforcesPace`; otherwise guidance shown in the app only.
    var pace: PaceRange?
    /// Optional name such as "Tempo". Shown in the app and on the Watch.
    var label: String?
}

nonisolated enum SegmentGoal: Codable, Hashable {
    case time(seconds: Int)
    case distance(meters: Int)
    case open

    static func minutes(_ minutes: Int) -> SegmentGoal { .time(seconds: minutes * 60) }
    static func seconds(_ seconds: Int) -> SegmentGoal { .time(seconds: seconds) }
    static func meters(_ meters: Int) -> SegmentGoal { .distance(meters: meters) }
    static func kilometers(_ kilometers: Int) -> SegmentGoal { .distance(meters: kilometers * 1000) }
}

/// A pace window in seconds per kilometre, e.g. 310…320 for 5:10–5:20/km.
nonisolated struct PaceRange: Codable, Hashable {
    var fastest: Int
    var slowest: Int
}

extension PaceRange {
    /// `PaceRange(5, 10, to: 5, 20)` reads as 5:10–5:20/km.
    init(_ fastMinutes: Int, _ fastSeconds: Int, to slowMinutes: Int, _ slowSeconds: Int) {
        self.init(fastest: fastMinutes * 60 + fastSeconds, slowest: slowMinutes * 60 + slowSeconds)
    }

    var midpoint: Int { (fastest + slowest) / 2 }
}
