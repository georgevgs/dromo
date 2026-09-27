import SwiftUI

/// Edits one session's targets, durations and repeats — e.g. after a fitness checkpoint.
/// The chart at the top reshapes as you go. If the session is already on the Watch, saving updates it there.
struct EditWorkoutView: View {
    @Environment(PlanStore.self) private var store
    @Environment(WatchSchedule.self) private var watch
    @Environment(\.dismiss) private var dismiss
    @Environment(\.paceScale) private var paceScale

    @State private var draft: PlannedWorkout

    init(workout: PlannedWorkout) {
        _draft = State(initialValue: workout)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StructureChart(workout: draft, height: 48)
                        .padding(.vertical, 8)
                } footer: {
                    Text("≈ \(DurationText.approximate(draft.estimatedSeconds(on: paceScale))) · ≈ \(DistanceText.kilometers(draft.estimatedMeters(on: paceScale)))")
                }

                Section("Name") {
                    TextField("Title", text: $draft.title)
                }

                if draft.warmup != nil {
                    Section {
                        SegmentEditor(segment: Binding($draft.warmup)!)
                    }
                }
                ForEach($draft.blocks) { $block in
                    Section {
                        if block.repeats > 1 || block.segments.count > 1 {
                            Stepper(value: $block.repeats, in: 1...20) {
                                LabeledContent("Rounds", value: block.repeats, format: .number)
                            }
                        }
                        ForEach($block.segments) { $segment in
                            SegmentEditor(segment: $segment)
                        }
                    } header: {
                        BlockHeader(block: block)
                    }
                }
                if draft.cooldown != nil {
                    Section {
                        SegmentEditor(segment: Binding($draft.cooldown)!)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: notes, axis: .vertical)
                }

                if let original = store.originalWorkout(id: draft.id) {
                    Section {
                        Button("Restore Original", systemImage: "arrow.counterclockwise") {
                            draft = original
                        }
                    } footer: {
                        Text("Puts back the plan's original version of this session. Takes effect when you save.")
                    }
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    } label: {
                        // Night ink on volt in both appearances; the system would pick white in Light Mode.
                        Text("Save").foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentFill)
                    .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var notes: Binding<String> {
        Binding(
            get: { draft.notes ?? "" },
            set: { text in
                // Emptying the field removes the notes rather than keeping an empty string.
                if text.isEmpty {
                    draft.notes = nil
                } else {
                    draft.notes = text
                }
            }
        )
    }

    private func save() {
        store.update(draft)
        if watch.isPending(draft) {
            Task { [draft] in _ = await watch.schedule(draft) }
        }
        dismiss()
    }
}

// MARK: - Segment editing

private struct SegmentEditor: View {
    @Binding var segment: WorkoutSegment

    var body: some View {
        GoalStepper(title: segment.name, goal: $segment.goal)
        if segment.pace != nil {
            PaceEditor(pace: Binding($segment.pace)!, isAlert: segment.kind.enforcesPace)
        }
    }
}

private struct GoalStepper: View {
    let title: String
    @Binding var goal: SegmentGoal

    var body: some View {
        switch goal {
        case .time(let seconds):
            Stepper {
                LabeledContent(title, value: goal.text)
            } onIncrement: {
                goal = .time(seconds: seconds + Self.timeStep(below: seconds + 1))
            } onDecrement: {
                goal = .time(seconds: max(5, seconds - Self.timeStep(below: seconds)))
            }
        case .distance(let meters):
            Stepper {
                LabeledContent(title, value: goal.text)
            } onIncrement: {
                goal = .distance(meters: meters + 100)
            } onDecrement: {
                goal = .distance(meters: max(100, meters - 100))
            }
        case .open:
            LabeledContent(title, value: goal.text)
        }
    }

    /// Finer steps for short efforts: 5 sec up to a minute, 15 sec up to five, then whole minutes.
    /// Symmetric, so stepping up and back down lands where you started.
    private static func timeStep(below seconds: Int) -> Int {
        if seconds <= 60 {
            return 5
        }
        if seconds <= 5 * 60 {
            return 15
        }
        return 60
    }
}

private struct PaceEditor: View {
    @Binding var pace: PaceRange
    /// A Watch pace alert, rather than guidance shown only in the app.
    let isAlert: Bool

    private var fromLabel: String {
        if isAlert {
            return "Alert from"
        }
        return "Guide from"
    }

    var body: some View {
        Stepper {
            LabeledContent(fromLabel, value: "\(DurationText.minutesSeconds(pace.fastest))/km")
        } onIncrement: {
            pace.fastest = min(pace.fastest + 1, pace.slowest)
        } onDecrement: {
            pace.fastest = max(pace.fastest - 1, 2 * 60)
        }
        Stepper {
            LabeledContent("to", value: "\(DurationText.minutesSeconds(pace.slowest))/km")
        } onIncrement: {
            pace.slowest = min(pace.slowest + 1, 15 * 60)
        } onDecrement: {
            pace.slowest = max(pace.slowest - 1, pace.fastest)
        }
    }
}

#Preview {
    EditWorkoutView(workout: BundledPlan.plan.workouts[7])
        .environment(PlanStore())
        .environment(WatchSchedule())
}
