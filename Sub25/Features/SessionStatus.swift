import WorkoutKit

extension PlanStore {
    /// A session's status right now, combining what's recorded here with what's on the Watch.
    func status(of workout: PlannedWorkout, on watch: WatchSchedule) -> WorkoutStatus {
        let entry = watch.entry(for: workout)
        return WorkoutStatus(
            date: workout.date,
            isCompleted: isCompleted(workout) || entry?.complete == true,
            isOnWatch: entry != nil
        )
    }
}
