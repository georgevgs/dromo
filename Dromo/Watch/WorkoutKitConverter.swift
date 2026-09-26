import Foundation
import HealthKit
import WorkoutKit

/// PlannedWorkout → WorkoutKit. The only place that knows how the plan maps onto WorkoutKit types.
enum WorkoutKitConverter {
    /// `.current` reacts within seconds and is what Apple's own sample uses for running.
    /// Switch to `.average` (average over the step) if alerts feel twitchy on GPS-noisy streets.
    static let paceAlertMetric: WorkoutAlertMetric = .current

    /// Training runs have no fixed start time. WorkoutKit needs one, so they get a nominal
    /// morning slot; the Watch still lets you start the workout any time.
    static let nominalStartTime = PlanTime(hour: 7, minute: 0)

    static func workoutPlan(for workout: PlannedWorkout) -> WorkoutPlan {
        WorkoutPlan(.custom(customWorkout(for: workout)), id: workout.id)
    }

    static func scheduleDate(for workout: PlannedWorkout) -> DateComponents {
        let time = workout.startTime ?? nominalStartTime
        let date = Calendar.athens.date(from: DateComponents(
            year: workout.date.year,
            month: workout.date.month,
            day: workout.date.day,
            hour: time.hour,
            minute: time.minute
        ))!
        // Every component, the same shape Apple's sample passes to schedule(_:at:).
        return Calendar.athens.dateComponents(in: .athens, from: date)
    }

    private static func customWorkout(for workout: PlannedWorkout) -> CustomWorkout {
        CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: workout.title,
            warmup: workout.warmup.map(step),
            blocks: workout.blocks.map(block),
            cooldown: workout.cooldown.map(step)
        )
    }

    private static func block(_ block: SegmentBlock) -> IntervalBlock {
        IntervalBlock(
            steps: block.segments.map { segment in
                IntervalStep(segment.kind == .recovery ? .recovery : .work, step: step(segment))
            },
            iterations: block.repeats
        )
    }

    private static func step(_ segment: WorkoutSegment) -> WorkoutStep {
        WorkoutStep(goal: goal(segment.goal), alert: alert(segment), displayName: watchName(segment))
    }

    private static func goal(_ goal: SegmentGoal) -> WorkoutGoal {
        switch goal {
        case .time(let seconds): .time(Double(seconds), .seconds)
        case .distance(let meters): .distance(Double(meters), .meters)
        case .open: .open
        }
    }

    /// WorkoutKit has no pace type: a pace window is a speed range, and the Watch shows it as pace for runs.
    private static func alert(_ segment: WorkoutSegment) -> (any WorkoutAlert)? {
        guard segment.kind.enforcesPace, let pace = segment.pace else { return nil }
        let slowest = Measurement(value: 1000 / Double(pace.slowest), unit: UnitSpeed.metersPerSecond)
        let fastest = Measurement(value: 1000 / Double(pace.fastest), unit: UnitSpeed.metersPerSecond)
        return SpeedRangeAlert(target: slowest...fastest, metric: paceAlertMetric)
    }

    /// nil keeps the Watch's own labels (Warmup, Work, Recovery, Cooldown).
    private static func watchName(_ segment: WorkoutSegment) -> String? {
        switch segment.kind {
        case .race:
            // Race splits go in the name — visible at a glance, never an alert.
            let name = segment.label ?? "Race"
            return segment.pace.map { "\(name) · \($0.shortText)" } ?? name
        case .easy:
            return segment.label ?? "Easy"
        case .stride:
            return segment.label ?? "Stride"
        case .warmup, .work, .recovery, .cooldown:
            return segment.label
        }
    }
}
