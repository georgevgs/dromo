import SwiftUI
import WorkoutKit

/// One session in full, with the action that puts it on the Watch.
struct WorkoutDetailView: View {
    let workoutID: PlannedWorkout.ID

    @Environment(PlanStore.self) private var store
    @Environment(WatchSchedule.self) private var watch

    @State private var isPreviewing = false
    @State private var isEditing = false
    @State private var isScheduling = false
    @State private var problem: String?
    @State private var successfulSchedules = 0

    var body: some View {
        // Read live from the store so edits show up here straight away.
        if let workout = store.workout(id: workoutID) {
            content(workout, status: store.status(of: workout, on: watch))
        }
    }

    private func content(_ workout: PlannedWorkout, status: WorkoutStatus) -> some View {
        List {
            Section {
                WorkoutHeader(workout: workout, status: status)
            }
            .listRowBackground(Color.clear)

            Section("Structure") {
                StructureChart(workout: workout, height: 64)
                    .padding(.vertical, 8)
            }

            if let warmup = workout.warmup {
                Section("Warm-up") { StepRow(segment: warmup) }
            }
            ForEach(workout.blocks) { block in
                Section {
                    ForEach(block.segments) { StepRow(segment: $0) }
                } header: {
                    BlockHeader(block: block)
                }
            }
            if let cooldown = workout.cooldown {
                Section("Cool-down") { StepRow(segment: cooldown) }
            }

            if let notes = workout.notes {
                Section("Notes") {
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                if status == .completed {
                    Button("Mark as Not Done", systemImage: "arrow.uturn.backward") {
                        store.setCompleted(workout, false)
                    }
                } else {
                    Button("Mark as Done", systemImage: "checkmark.circle") {
                        store.setCompleted(workout, true)
                    }
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            if workout.date >= .today && status != .completed {
                actionBar(for: workout, status: status)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditWorkoutView(workout: workout)
                .environment(store)
                .environment(watch)
        }
        .workoutPreview(WorkoutKitConverter.workoutPlan(for: workout), isPresented: $isPreviewing)
        .alert("Couldn't Schedule", isPresented: isShowingProblem) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
        .sensoryFeedback(.success, trigger: successfulSchedules)
    }

    /// Liquid Glass controls floating over the content, as the HIG prescribes for actions.
    private func actionBar(for workout: PlannedWorkout, status: WorkoutStatus) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { await schedule(workout) }
                } label: {
                    Label(sendTitle(status), systemImage: "applewatch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentFill)
                .foregroundStyle(.onAccent)
                .disabled(isScheduling)

                Button("Preview", systemImage: "eye") {
                    isPreviewing = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .accessibilityShowsLargeContentViewer()
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func sendTitle(_ status: WorkoutStatus) -> String {
        if status == .onWatch {
            return "Update on Apple Watch"
        }
        return "Send to Apple Watch"
    }

    private var isShowingProblem: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }

    private func schedule(_ workout: PlannedWorkout) async {
        isScheduling = true
        defer { isScheduling = false }

        if await watch.schedule(workout) {
            successfulSchedules += 1
        } else {
            problem =
                if !watch.isSupported {
                    "No paired Apple Watch found."
                } else if watch.isDenied {
                    "Dromo isn't allowed to schedule workouts. You can allow it in Settings."
                } else {
                    "The system didn't accept the workout. Pull to refresh on the plan and try again."
                }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workoutID: BundledPlan.plan.workouts[1].id)
    }
    .environment(PlanStore())
    .environment(WatchSchedule())
}
