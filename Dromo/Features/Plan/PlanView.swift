import SwiftUI
import UIKit

/// Home: the race, the next session, and the whole plan week by week.
struct PlanView: View {
    @Environment(PlanStore.self) private var store
    @Environment(WatchSchedule.self) private var watch
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var isSyncing = false
    @State private var syncNote: String?
    @State private var successfulSyncs = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    RaceHeader(plan: store.plan, progress: progress)
                }
                .listRowBackground(Theme.hero)

                if let next = nextWorkout {
                    Section {
                        NavigationLink(value: next.id) {
                            UpNextCard(workout: next, status: status(of: next))
                        }
                    } header: {
                        Text("Up Next")
                    } footer: {
                        watchFooter
                    }
                }

                ForEach(store.plan.weeks) { week in
                    Section {
                        ForEach(week.workouts) { workout in
                            row(for: workout)
                        }
                    } header: {
                        HStack {
                            Text(week.title)
                            Spacer()
                            if let range = week.dateRangeText {
                                Text(range)
                            }
                        }
                    }
                }
            }
            .navigationTitle(store.plan.title)
            .navigationDestination(for: PlannedWorkout.ID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    syncButton
                }
            }
            .refreshable { await refresh() }
            // Picks up sessions completed on the Watch whenever the app comes back to the foreground.
            .task(id: scenePhase) {
                if scenePhase == .active { await refresh() }
            }
            .sensoryFeedback(.success, trigger: successfulSyncs)
        }
    }

    // MARK: - Rows

    private func row(for workout: PlannedWorkout) -> some View {
        let status = status(of: workout)
        return NavigationLink(value: workout.id) {
            WorkoutRow(workout: workout, status: status)
        }
        .swipeActions(edge: .leading) {
            Button(status == .completed ? "Not Done" : "Done",
                   systemImage: status == .completed ? "arrow.uturn.backward" : "checkmark") {
                store.setCompleted(workout, status != .completed)
            }
            .tint(.done)
        }
    }

    // MARK: - Apple Watch

    private var syncButton: some View {
        Button("Sync to Apple Watch", systemImage: "arrow.triangle.2.circlepath") {
            Task { await sync() }
        }
        .symbolEffect(.rotate, isActive: isSyncing)
        .buttonStyle(.glassProminent)
        .disabled(isSyncing || !watch.isSupported || watch.isDenied)
    }

    @ViewBuilder
    private var watchFooter: some View {
        if !watch.isSupported {
            Text("No paired Apple Watch found.")
        } else if watch.isDenied {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dromo isn't allowed to schedule workouts on your Apple Watch.")
                Button("Allow in Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.footnote.weight(.semibold))
            }
        } else if let syncNote {
            Text(syncNote)
        } else {
            Text("Tap \(Image(systemName: "arrow.triangle.2.circlepath")) to put the next 7 days on your Apple Watch. They appear at the top of the Workout app.")
        }
    }

    private func refresh() async {
        await watch.refresh()
        store.recordCompleted(watch.completedIDs)
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        guard let upcoming = await watch.sync(store.plan.workouts, completed: store.completedIDs) else {
            syncNote = nil
            return
        }
        store.recordCompleted(watch.completedIDs)

        let missing = upcoming.filter { watch.entry(for: $0) == nil }
        if missing.isEmpty {
            successfulSyncs += 1
        }
        syncNote =
            if upcoming.isEmpty {
                "Nothing planned in the next 7 days."
            } else if missing.isEmpty {
                "On your Watch: " + upcoming.map { "\($0.date.shortText) \($0.title)" }.joined(separator: ", ") + "."
            } else {
                "Couldn't add " + missing.map(\.title).joined(separator: ", ") + ". Try again."
            }
    }

    // MARK: - Derived state

    private func status(of workout: PlannedWorkout) -> WorkoutStatus {
        store.status(of: workout, on: watch)
    }

    /// The first session from today on that isn't done yet.
    private var nextWorkout: PlannedWorkout? {
        store.plan.workouts.first { $0.date >= .today && status(of: $0) != .completed }
    }

    private var progress: [[PlanProgress.Session]] {
        store.plan.weeks.map { week in
            week.workouts.map { .init(id: $0.id, status: status(of: $0), isToday: $0.date == .today) }
        }
    }
}

#Preview {
    PlanView()
        .environment(PlanStore())
        .environment(WatchSchedule())
}
