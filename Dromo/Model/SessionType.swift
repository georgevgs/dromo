import Foundation

/// What kind of session a workout is, derived from its segments rather than stored,
/// so an edited workout is always described correctly.
enum SessionType {
    /// Easy running only.
    case easy
    /// Easy running finished with short relaxed strides.
    case strides
    /// Repeated efforts held to a pace.
    case intervals
    /// One sustained effort held to a pace: tempo, progression, race-pace rehearsal.
    case steady
    case race

    init(_ workout: PlannedWorkout) {
        let kinds = Set(workout.segments.map(\.kind))
        let hasRepeatedWork = workout.blocks.contains { block in
            block.repeats > 1 && block.segments.contains { $0.kind == .work }
        }

        self =
            if kinds.contains(.race) { .race }
            else if hasRepeatedWork { .intervals }
            else if kinds.contains(.work) { .steady }
            else if kinds.contains(.stride) { .strides }
            else { .easy }
    }

    var name: String {
        switch self {
        case .easy: "Easy run"
        case .strides: "Easy + strides"
        case .intervals: "Intervals"
        case .steady: "Steady effort"
        case .race: "Race"
        }
    }
}
