import Foundation
import Observation
import WorkoutKit

// A plain Int-backed enum that WorkoutKit just hasn't annotated as Sendable.
extension WorkoutScheduler.AuthorizationState: @retroactive @unchecked Sendable {}

/// Wraps `WorkoutScheduler`, which hands workouts to the Workout app on the paired Apple Watch.
/// Once a workout is there, the Watch runs it on its own — the iPhone isn't needed.
@Observable
final class WatchSchedule {
    /// The Workout app shows scheduled workouts for the next seven days, so that's what sync keeps filled.
    static let syncWindowDays = 7

    private(set) var authorization: WorkoutScheduler.AuthorizationState = .notDetermined
    /// What the system currently holds for this app — the source of truth for "is it on the Watch".
    private(set) var scheduled: [ScheduledWorkoutPlan] = []

    private let scheduler = WorkoutScheduler.shared

    /// False when there's no paired Apple Watch.
    var isSupported: Bool { WorkoutScheduler.isSupported }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func refresh() async {
        authorization = await scheduler.authorizationState
        if authorization == .authorized {
            scheduled = await scheduler.scheduledWorkouts
        } else {
            scheduled = []
        }
    }

    func entry(for workout: PlannedWorkout) -> ScheduledWorkoutPlan? {
        scheduled.first { $0.plan.id == workout.id }
    }

    /// On the Watch and not yet done there.
    func isPending(_ workout: PlannedWorkout) -> Bool {
        guard let entry = entry(for: workout) else { return false }
        return !entry.complete
    }

    var completedIDs: [PlannedWorkout.ID] {
        scheduled.filter(\.complete).map(\.plan.id)
    }

    /// Puts one workout on the Watch at its planned date, replacing any copy already there.
    /// Returns whether the system now lists it.
    func schedule(_ workout: PlannedWorkout) async -> Bool {
        guard await isAuthorized() else { return false }

        for entry in scheduled where entry.plan.id == workout.id {
            await scheduler.remove(entry.plan, at: entry.date)
        }
        await add(workout)
        await refresh()
        return entry(for: workout) != nil
    }

    /// Brings the Watch in line with the plan — see `SyncPlan` for the rules.
    /// Returns the sessions in the window still to do, or nil without permission.
    func sync(_ plan: [PlannedWorkout], completed: Set<PlannedWorkout.ID>) async -> [PlannedWorkout]? {
        guard await isAuthorized() else { return nil }
        await refresh()

        let changes = SyncPlan(
            plan: plan,
            completed: completed,
            onWatch: scheduled,
            today: .today,
            windowDays: Self.syncWindowDays
        )
        for entry in changes.removals {
            await scheduler.remove(entry.plan, at: entry.date)
        }
        for workout in changes.additions {
            await add(workout)
        }
        await refresh()
        return changes.upcoming
    }

    private func add(_ workout: PlannedWorkout) async {
        let plan = WorkoutKitConverter.workoutPlan(for: workout)
        await scheduler.schedule(plan, at: WorkoutKitConverter.scheduleDate(for: workout))
    }

    /// Asks for permission the first time it's needed.
    private func isAuthorized() async -> Bool {
        if authorization == .notDetermined {
            authorization = await scheduler.requestAuthorization()
        }
        return authorization == .authorized
    }
}
