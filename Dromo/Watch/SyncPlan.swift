import Foundation
import WorkoutKit

/// What has to change on the Watch for it to match the plan.
///
/// Pure — it compares values and never calls the scheduler — so the rules are easy to read and test:
/// - Every session still to do in the next `windowDays` days gets onto the Watch.
/// - A future session already there stays, as long as it's the current version at the right time.
/// - Completed plan sessions stay as history.
/// - Everything else goes: edited versions, missed sessions, anything that isn't part of the plan.
/// - Missed sessions are never moved to a later day. The plan doesn't chase them.
struct SyncPlan {
    /// The sessions from today through the window that are still to do.
    let upcoming: [PlannedWorkout]
    let removals: [ScheduledWorkoutPlan]
    let additions: [PlannedWorkout]

    init(
        plan: [PlannedWorkout],
        completed: Set<PlannedWorkout.ID>,
        onWatch: [ScheduledWorkoutPlan],
        today: PlanDate,
        windowDays: Int
    ) {
        let windowEnd = today.adding(days: windowDays)
        let planIDs = Set(plan.map(\.id))
        let pending = plan.filter { $0.date >= today && !completed.contains($0.id) }
        let pendingByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })

        var removals: [ScheduledWorkoutPlan] = []
        var current = Set<PlannedWorkout.ID>()
        for entry in onWatch {
            if entry.complete && planIDs.contains(entry.plan.id) {
                continue
            }
            if !entry.complete, !current.contains(entry.plan.id),
               let workout = pendingByID[entry.plan.id], Self.matches(entry, workout) {
                current.insert(workout.id)
            } else {
                removals.append(entry)
            }
        }

        let completedOnWatch = Set(onWatch.filter(\.complete).map(\.plan.id))
        upcoming = pending.filter { $0.date < windowEnd }
        additions = upcoming.filter { !current.contains($0.id) && !completedOnWatch.contains($0.id) }
        self.removals = removals
    }

    /// Same content at the same time as the plan says now.
    private static func matches(_ entry: ScheduledWorkoutPlan, _ workout: PlannedWorkout) -> Bool {
        let plannedDate = Calendar.plan.date(from: WorkoutKitConverter.scheduleDate(for: workout))
        return entry.plan == WorkoutKitConverter.workoutPlan(for: workout)
            && Calendar.plan.date(from: entry.date) == plannedDate
    }
}
