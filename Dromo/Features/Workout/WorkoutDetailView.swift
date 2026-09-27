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

            Group {
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
            .listRowBackground(Theme.glass)
        }
        // The session glows in its type's colour: heat, ice or ultraviolet.
        .floodlight(glow: SessionType(workout).tint, secondGlow: .clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(status == .completed ? "Mark as Not Done" : "Mark as Done",
                       systemImage: status == .completed ? "arrow.uturn.backward" : "checkmark.circle") {
                    store.setCompleted(workout, status != .completed)
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
                    Label(status == .onWatch ? "Update on Apple Watch" : "Send to Apple Watch", systemImage: "applewatch")
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
        WorkoutDetailView(workoutID: DefaultPlan.plan.workouts[1].id)
    }
    .environment(PlanStore())
    .environment(WatchSchedule())
}
