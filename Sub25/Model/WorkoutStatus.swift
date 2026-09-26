import Foundation

/// Where a session stands. Completion wins, then the calendar, then the Watch.
enum WorkoutStatus: Equatable {
    case upcoming
    case onWatch
    case completed
    /// In the past and not done. Never rescheduled — the plan doesn't chase missed sessions.
    case missed

    init(date: PlanDate, isCompleted: Bool, isOnWatch: Bool, today: PlanDate = .today) {
        self =
            if isCompleted { .completed }
            else if date < today { .missed }
            else if isOnWatch { .onWatch }
            else { .upcoming }
    }
}
