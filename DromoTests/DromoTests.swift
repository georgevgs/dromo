import Foundation
import HealthKit
import Testing
import WorkoutKit
@testable import Dromo

// The rules that, if broken, would silently put the wrong workout on the Watch.

struct PlanTests {
    let workouts = BundledPlan.plan.workouts

    @Test func eighteenSessionsOnMondaysThursdaysAndSaturdays() {
        #expect(workouts.count == 18)
        #expect(Set(workouts.map(\.id)).count == 18)
        let weekdays = Set(workouts.map { Calendar.plan.component(.weekday, from: $0.date.startOfDay) })
        #expect(weekdays == [2, 5, 7])
    }

    @Test func onlyQualityWorkGetsPaceAlerts() throws {
        for workout in workouts {
            let custom = try #require(workout.customWorkout)
            let repeated = custom.blocks.flatMap { block in
                Array(repeating: block.steps.map(\.step), count: block.iterations).flatMap(\.self)
            }
            let alerts = ([custom.warmup] + repeated + [custom.cooldown]).compactMap { $0?.alert }
            let pacedWork = workout.timeline.filter { $0.kind == .work }
            #expect(alerts.count == pacedWork.count, "\(workout.title)")
            #expect(alerts.allSatisfy { CustomWorkout.supportsAlert($0, activity: .running, location: .outdoor) })
        }
    }

    @Test func paceWindowBecomesTheMatchingSpeedRange() throws {
        let thursday = try #require(workouts.first { $0.title == "6 × 90 sec" })
        let custom = try #require(thursday.customWorkout)
        let alert = try #require(custom.blocks[0].steps[0].step.alert as? SpeedRangeAlert)
        #expect(custom.blocks[0].iterations == 6)
        #expect(abs(alert.target.lowerBound.converted(to: .metersPerSecond).value - 1000 / 320) < 0.001)  // 5:20/km
        #expect(abs(alert.target.upperBound.converted(to: .metersPerSecond).value - 1000 / 310) < 0.001)  // 5:10/km
    }
}

struct SyncPlanTests {
    let workouts = BundledPlan.plan.workouts
    let saturdayBeforeTheStart = PlanDate(2026, 9, 26)

    @Test func fillsTheNextSevenDays() {
        let sync = SyncPlan(plan: workouts, completed: [], onWatch: [], today: saturdayBeforeTheStart, windowDays: 7)
        #expect(sync.additions.map(\.date) == [PlanDate(2026, 9, 28), PlanDate(2026, 10, 1)])
        #expect(sync.removals.isEmpty)
    }

    @Test func keepsCurrentSessionsAndReplacesEditedOnes() {
        var plan = workouts
        let original = plan[1]
        plan[1].title = "Edited"
        let onWatch = [entry(for: plan[0]), entry(for: original)]

        let sync = SyncPlan(plan: plan, completed: [], onWatch: onWatch, today: saturdayBeforeTheStart, windowDays: 7)

        #expect(sync.additions.map(\.title) == ["Edited"])
        #expect(sync.removals.map(\.plan.id) == [original.id])
    }

    @Test func clearsMissedAndStrayEntriesButKeepsCompletedOnes() {
        let missedMonday = entry(for: workouts[0])
        var doneThursday = entry(for: workouts[1])
        doneThursday.complete = true
        let stray = ScheduledWorkoutPlan(
            WorkoutPlan(.custom(CustomWorkout(activity: .running, location: .outdoor))),
            date: WorkoutKitConverter.scheduleDate(for: workouts[2])
        )
        let friday = PlanDate(2026, 10, 2)

        let onWatch = [missedMonday, doneThursday, stray]
        let sync = SyncPlan(plan: workouts, completed: [], onWatch: onWatch, today: friday, windowDays: 7)

        #expect(sync.removals.map(\.plan.id) == [missedMonday.plan.id, stray.plan.id])
        #expect(sync.additions.map(\.date) == [PlanDate(2026, 10, 3), PlanDate(2026, 10, 5), PlanDate(2026, 10, 8)])
    }

    private func entry(for workout: PlannedWorkout) -> ScheduledWorkoutPlan {
        let plan = WorkoutKitConverter.workoutPlan(for: workout)
        return ScheduledWorkoutPlan(plan, date: WorkoutKitConverter.scheduleDate(for: workout))
    }
}

private extension PlannedWorkout {
    var customWorkout: CustomWorkout? {
        if case .custom(let custom) = WorkoutKitConverter.workoutPlan(for: self).workout { custom } else { nil }
    }
}
