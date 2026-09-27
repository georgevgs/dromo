import Foundation

// Rough time and distance for each segment, so the app can show how long a session takes
// and draw its shape. Estimates only — the Watch measures the real thing.

/// The paces a plan is written around, so estimates and effort fit the runner it's for.
struct PaceScale: Hashable {
    /// Seconds per kilometre for running that has no pace of its own: easy running, warm-ups, recoveries.
    var easy: Int
    /// The fastest paced running in the plan, which tops the effort scale.
    var fastest: Int

    /// For a plan with no paces to go by: 6:35/km easy, 4:40/km fast.
    static let standard = PaceScale(easy: 6 * 60 + 35, fastest: 4 * 60 + 40)
}

extension TrainingPlan {
    /// Easy is the middle of the plan's easy-run guides; fastest is the quickest end of its paced work.
    /// Whatever the plan doesn't say comes from `PaceScale.standard`.
    var paceScale: PaceScale {
        var scale = PaceScale.standard
        let segments = workouts.flatMap(\.segments)

        let easyGuides = segments.filter { $0.kind == .easy }.compactMap { $0.pace?.midpoint }.sorted()
        if !easyGuides.isEmpty {
            scale.easy = easyGuides[easyGuides.count / 2]
        }
        let workPaces = segments.filter { $0.kind == .work || $0.kind == .race }.compactMap { $0.pace?.fastest }
        if let fastest = workPaces.min() {
            scale.fastest = fastest
        }

        // A scale needs room between its ends; a plan too uniform to give one gets the standard scale.
        if scale.fastest >= scale.easy {
            return .standard
        }
        return scale
    }
}

extension WorkoutSegment {
    /// The pace this segment is expected to be run at, in seconds per kilometre.
    func expectedPace(on scale: PaceScale) -> Int {
        pace?.midpoint ?? scale.easy
    }

    func estimatedSeconds(on scale: PaceScale) -> Int {
        switch goal {
        case .time(let seconds):
            return seconds
        case .distance(let meters):
            return meters * expectedPace(on: scale) / 1000
        case .open:
            // An open step lasts as long as the runner decides. With a pace (a race's last split),
            // assume a kilometre at it; without one, there's nothing to go on.
            if pace == nil {
                return 0
            }
            return expectedPace(on: scale)
        }
    }

    func estimatedMeters(on scale: PaceScale) -> Int {
        switch goal {
        case .time(let seconds):
            return seconds * 1000 / expectedPace(on: scale)
        case .distance(let meters):
            return meters
        case .open:
            if pace == nil {
                return 0
            }
            return 1000
        }
    }

    /// Relative effort from 0 (standing) to 1 (flat out). Used for the height of structure bars.
    func intensity(on scale: PaceScale) -> Double {
        switch kind {
        case .recovery:
            return 0.28
        case .warmup, .cooldown, .easy:
            return 0.45
        case .stride:
            return 0.95
        case .race:
            return 1
        case .work:
            // Scales from moderate at easy pace to near-maximal at the plan's fastest.
            let fraction = Double(scale.easy - expectedPace(on: scale)) / Double(scale.easy - scale.fastest)
            return 0.6 + 0.4 * min(max(fraction, 0), 1)
        }
    }
}

extension PlannedWorkout {
    func estimatedSeconds(on scale: PaceScale) -> Int {
        timeline.map { $0.estimatedSeconds(on: scale) }.reduce(0, +)
    }

    func estimatedMeters(on scale: PaceScale) -> Int {
        timeline.map { $0.estimatedMeters(on: scale) }.reduce(0, +)
    }
}
