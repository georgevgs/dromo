import Foundation

// Rough time and distance for each segment, so the app can show how long a session takes
// and draw its shape. Estimates only — the Watch measures the real thing.

extension WorkoutSegment {
    /// A typical easy pace, used when a segment has no pace of its own: 6:35/km.
    static let typicalEasyPace = 6 * 60 + 35

    /// The pace this segment is expected to be run at, in seconds per kilometre.
    var expectedPace: Int {
        pace?.midpoint ?? Self.typicalEasyPace
    }

    var estimatedSeconds: Int {
        switch goal {
        case .time(let seconds): seconds
        case .distance(let meters): meters * expectedPace / 1000
        // An open step lasts as long as the runner decides. The only one in the plan is the race's
        // last kilometre, so assume a kilometre at its pace.
        case .open: pace == nil ? 0 : expectedPace
        }
    }

    var estimatedMeters: Int {
        switch goal {
        case .time(let seconds): seconds * 1000 / expectedPace
        case .distance(let meters): meters
        case .open: pace == nil ? 0 : 1000
        }
    }

    /// Relative effort from 0 (standing) to 1 (flat out). Used for the height of structure bars.
    var intensity: Double {
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
            // Scales from moderate at 6:30/km to near-maximal at 4:40/km, the range this plan spans.
            let fraction = Double(6 * 60 + 30 - expectedPace) / Double(6 * 60 + 30 - (4 * 60 + 40))
            return 0.6 + 0.4 * min(max(fraction, 0), 1)
        }
    }
}

extension PlannedWorkout {
    var estimatedSeconds: Int {
        timeline.map(\.estimatedSeconds).reduce(0, +)
    }

    var estimatedMeters: Int {
        timeline.map(\.estimatedMeters).reduce(0, +)
    }
}
