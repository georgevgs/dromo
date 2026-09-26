import Foundation

// The training plan as plain values, independent of WorkoutKit. The app owns the whole plan;
// WorkoutKit only ever receives converted copies of single workouts (see `WorkoutKitConverter`).

// MARK: - Plan

struct TrainingPlan: Codable, Hashable {
    var title: String
    var raceName: String
    var raceDate: PlanDate
    var raceDistanceMeters: Int
    var goalTimeSeconds: Int
    var weeks: [TrainingWeek]
}

extension TrainingPlan {
    /// Every session in date order.
    var workouts: [PlannedWorkout] {
        weeks.flatMap(\.workouts)
    }

    var raceWorkout: PlannedWorkout? {
        workouts.first { $0.date == raceDate }
    }

    /// Average pace the goal needs, rounded down to whole seconds: 24:59 over 5 km → 4:59/km.
    var goalPaceSecondsPerKm: Int {
        goalTimeSeconds * 1000 / raceDistanceMeters
    }
}

struct TrainingWeek: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var workouts: [PlannedWorkout]
}

// MARK: - Workout

struct PlannedWorkout: Codable, Hashable, Identifiable {
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
struct SegmentBlock: Codable, Hashable, Identifiable {
    var id = UUID()
    var repeats = 1
    var segments: [WorkoutSegment]
}

struct WorkoutSegment: Codable, Hashable, Identifiable {
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

enum SegmentGoal: Codable, Hashable {
    case time(seconds: Int)
    case distance(meters: Int)
    case open

    static func minutes(_ minutes: Int) -> SegmentGoal { .time(seconds: minutes * 60) }
    static func seconds(_ seconds: Int) -> SegmentGoal { .time(seconds: seconds) }
    static func meters(_ meters: Int) -> SegmentGoal { .distance(meters: meters) }
    static func kilometers(_ kilometers: Int) -> SegmentGoal { .distance(meters: kilometers * 1000) }
}

/// A pace window in seconds per kilometre, e.g. 310…320 for 5:10–5:20/km.
struct PaceRange: Codable, Hashable {
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
