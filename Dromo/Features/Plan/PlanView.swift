import SwiftUI
import UIKit
import WorkoutKit

/// Home: the race, the next session, and the whole plan week by week.
struct PlanView: View {
    @Environment(PlanStore.self) private var store
    @Environment(WatchSchedule.self) private var watch
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isSyncing = false
    @State private var syncNote: String?
    @State private var successfulSyncs = 0
    @State private var newPlanRequest: NewPlanRequest?
    @State private var imports = 0
    /// The title of the plan just replaced, while its undo is on offer.
    @State private var replacedTitle: String?

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
                        weekHeader(week)
                    }
                }
            }
            .navigationTitle(store.plan.title)
            .navigationDestination(for: PlannedWorkout.ID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
            .toolbar {
                // Share links stay out of toolbar menus: iOS can't anchor a share sheet to a menu that has
                // already closed, and crashes. Sync, the one prominent action, stays trailing.
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: SharedPlan(plan: store.plan), preview: SharePreview(store.plan.title)) {
                        Label("Share Plan", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Plan", systemImage: "plus") {
                        newPlanRequest = NewPlanRequest()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    syncButton
                }
            }
            .sheet(item: $newPlanRequest) { request in
                NewPlanView(current: store.plan, sharedText: request.sharedText) { plan in
                    replace(with: plan)
                }
            }
            // "Open in Dromo" on a plan file from another app, such as a chat or Files.
            .onOpenURL { url in
                newPlanRequest = NewPlanRequest(sharedText: openedFileText(url))
            }
            .safeAreaBar(edge: .bottom) {
                if let replacedTitle {
                    undoBar(replacedTitle)
                }
            }
            // The undo is on offer for ten seconds; replacing again starts the count over.
            .task(id: replacedTitle) {
                guard replacedTitle != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(10))
                    withAnimation {
                        replacedTitle = nil
                    }
                } catch {
                    // Replaced again or undone before the time was up.
                }
            }
            .refreshable { await refresh() }
            // Whenever the app comes to the front: a plan sent with the share extension,
            // and sessions completed on the Watch.
            .task(id: scenePhase) {
                if scenePhase == .active {
                    if let text = PlanInbox.take() {
                        newPlanRequest = NewPlanRequest(sharedText: text)
                    }
                    await refresh()
                }
            }
            .sensoryFeedback(.success, trigger: successfulSyncs)
            .sensoryFeedback(.success, trigger: imports)
        }
    }

    // MARK: - Rows

    private func row(for workout: PlannedWorkout) -> some View {
        let status = status(of: workout)
        return NavigationLink(value: workout.id) {
            WorkoutRow(workout: workout, status: status)
        }
        .swipeActions(edge: .leading) {
            if status == .completed {
                Button("Not Done", systemImage: "arrow.uturn.backward") {
                    store.setCompleted(workout, false)
                }
                .tint(Theme.doneAction)
            } else {
                Button("Done", systemImage: "checkmark") {
                    store.setCompleted(workout, true)
                }
                .tint(Theme.doneAction)
            }
        }
    }

    /// "Week 1" and its dates on one line, or stacked when they don't fit (large text sizes).
    private func weekHeader(_ week: TrainingWeek) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(week.title)
                Spacer()
                if let range = week.dateRangeText {
                    Text(range)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(week.title)
                if let range = week.dateRangeText {
                    Text(range)
                }
            }
        }
    }

    // MARK: - Apple Watch

    private var syncButton: some View {
        Button("Sync to Apple Watch", systemImage: "arrow.triangle.2.circlepath") {
            Task { await sync() }
        }
        .symbolEffect(.rotate, isActive: isSyncing && !reduceMotion)
        .buttonStyle(.glassProminent)
        .tint(.accentFill)
        .foregroundStyle(.onAccent)
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

    // MARK: - New plans

    /// A new plan replaces the old one; if Dromo may already use the Watch, the Watch follows straight away.
    private func replace(with plan: TrainingPlan) {
        let oldTitle = store.plan.title
        store.replace(with: plan)
        syncNote = nil
        imports += 1
        withAnimation {
            replacedTitle = oldTitle
        }
        syncIfAllowed()
    }

    private func undoReplace() {
        store.undoReplace()
        syncNote = nil
        withAnimation {
            replacedTitle = nil
        }
        syncIfAllowed()
    }

    /// Only when Dromo already has permission: a replace or undo shouldn't be what asks for it.
    private func syncIfAllowed() {
        if watch.authorization == .authorized {
            Task { await sync() }
        }
    }

    private func undoBar(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text("Replaced “\(title)”")
                .font(.subheadline)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Undo") {
                undoReplace()
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// iOS hands an opened file over as a copy in the app's Inbox folder: read it, then tidy it away.
    private func openedFileText(_ url: URL) -> String {
        let text = NewPlanView.text(of: url) ?? ""
        if url.path().hasPrefix(URL.documentsDirectory.path()) {
            try? FileManager.default.removeItem(at: url)
        }
        return text
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
