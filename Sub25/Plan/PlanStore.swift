import Foundation
import Observation
import os

/// Owns the training plan and keeps it on the device. No backend, no account.
/// The built-in plan is used until something is edited; from then on the saved copy wins.
@Observable
final class PlanStore {
    private(set) var plan: TrainingPlan
    /// Workouts done — completed on the Watch or marked by hand. Kept here because the system
    /// eventually drops old scheduled workouts, and their completion flag with them.
    private(set) var completedIDs: Set<UUID>

    private let fileURL = URL.applicationSupportDirectory.appending(path: "TrainingPlan.json")
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "eu.vagdas.sub25", category: "PlanStore")
    private static let completedKey = "completedWorkoutIDs"

    init() {
        let plan = if let data = try? Data(contentsOf: fileURL),
                      let saved = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
            saved
        } else {
            DefaultPlan.plan
        }
        self.plan = plan
        let completed = (defaults.stringArray(forKey: Self.completedKey) ?? []).compactMap(UUID.init(uuidString:))
        completedIDs = Set(completed).intersection(plan.workouts.map(\.id))
    }

    func workout(id: PlannedWorkout.ID) -> PlannedWorkout? {
        plan.workouts.first { $0.id == id }
    }

    func update(_ workout: PlannedWorkout) {
        for week in plan.weeks.indices {
            if let index = plan.weeks[week].workouts.firstIndex(where: { $0.id == workout.id }) {
                plan.weeks[week].workouts[index] = workout
                save()
                return
            }
        }
    }

    // MARK: - Completion

    func isCompleted(_ workout: PlannedWorkout) -> Bool {
        completedIDs.contains(workout.id)
    }

    func setCompleted(_ workout: PlannedWorkout, _ isCompleted: Bool) {
        if isCompleted {
            completedIDs.insert(workout.id)
        } else {
            completedIDs.remove(workout.id)
        }
        saveCompleted()
    }

    /// Adds completions reported by the Watch, ignoring anything that isn't part of the plan.
    func recordCompleted(_ ids: some Sequence<UUID>) {
        let updated = completedIDs.union(ids.filter { workout(id: $0) != nil })
        guard updated != completedIDs else { return }
        completedIDs = updated
        saveCompleted()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(plan).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Couldn't save plan: \(error)")
        }
    }

    private func saveCompleted() {
        defaults.set(completedIDs.map(\.uuidString), forKey: Self.completedKey)
    }
}
