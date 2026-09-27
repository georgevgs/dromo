import Foundation
import Observation
import os

/// Owns the training plan and keeps it on the device. No backend, no account.
/// The built-in plan is used until one is imported or something is edited; from then on the saved copy wins.
@Observable
final class PlanStore {
    private(set) var plan: TrainingPlan
    /// The plan as imported (or built in), before any edits: what "Restore Original" goes back to.
    private(set) var original: TrainingPlan
    /// Workouts done — completed on the Watch or marked by hand. Kept here because the system
    /// eventually drops old scheduled workouts, and their completion flag with them.
    private(set) var completedIDs: Set<UUID>

    /// Everything a replace changes, kept from just before the last one so it can be undone.
    /// Only until the app quits: undo is for "that wasn't the plan I meant", right after replacing.
    private struct Snapshot {
        let plan: TrainingPlan
        let original: TrainingPlan
        let completedIDs: Set<UUID>
    }

    private var beforeReplace: Snapshot?

    private let fileURL = URL.applicationSupportDirectory.appending(path: "TrainingPlan.json")
    private let originalURL = URL.applicationSupportDirectory.appending(path: "ImportedPlan.json")
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "eu.vagdas.sub25", category: "PlanStore")
    private static let completedKey = "completedWorkoutIDs"

    init() {
        let original = Self.load(originalURL) ?? BundledPlan.plan
        let plan = Self.load(fileURL) ?? original
        self.original = original
        self.plan = plan
        let completed = (defaults.stringArray(forKey: Self.completedKey) ?? []).compactMap(UUID.init(uuidString:))
        completedIDs = Set(completed).intersection(plan.workouts.map(\.id))
    }

    func workout(id: PlannedWorkout.ID) -> PlannedWorkout? {
        plan.workouts.first { $0.id == id }
    }

    func originalWorkout(id: PlannedWorkout.ID) -> PlannedWorkout? {
        original.workouts.first { $0.id == id }
    }

    /// Swaps in a new plan. Sessions keep their done marks where the new plan has a session with the same ID,
    /// which is the same day (see `PlanFile.workoutID`) — so re-importing an adjusted plan loses nothing.
    func replace(with plan: TrainingPlan) {
        beforeReplace = Snapshot(plan: self.plan, original: original, completedIDs: completedIDs)
        self.plan = plan
        original = plan
        save(plan, to: fileURL)
        save(plan, to: originalURL)
        let kept = completedIDs.intersection(plan.workouts.map(\.id))
        if kept != completedIDs {
            completedIDs = kept
            saveCompleted()
        }
    }

    /// Puts back the plan from before the last replace, with its edits and done marks.
    func undoReplace() {
        guard let before = beforeReplace else { return }
        plan = before.plan
        original = before.original
        completedIDs = before.completedIDs
        save(plan, to: fileURL)
        save(original, to: originalURL)
        saveCompleted()
        beforeReplace = nil
    }

    func update(_ workout: PlannedWorkout) {
        for week in plan.weeks.indices {
            if let index = plan.weeks[week].workouts.firstIndex(where: { $0.id == workout.id }) {
                plan.weeks[week].workouts[index] = workout
                save(plan, to: fileURL)
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

    private static func load(_ url: URL) -> TrainingPlan? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TrainingPlan.self, from: data)
    }

    private func save(_ plan: TrainingPlan, to url: URL) {
        do {
            let folder = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(plan).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save plan: \(error)")
        }
    }

    private func saveCompleted() {
        defaults.set(completedIDs.map(\.uuidString), forKey: Self.completedKey)
    }
}
