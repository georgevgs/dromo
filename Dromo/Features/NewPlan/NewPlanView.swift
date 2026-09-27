import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Opens the New Plan sheet: empty, or with a plan shared to Dromo from another app —
/// a file opened in Dromo, or a chat's reply sent with the share extension.
struct NewPlanRequest: Identifiable {
    let id = UUID()
    var sharedText: String?
}

/// Brings in a plan an AI chat wrote: copy the prompt for the chat, paste its reply (or choose the file it made),
/// see what Dromo read, then replace the current plan. Nothing changes until Replace, so this sheet is the
/// confirmation it needs. Sharing the current plan out is the plan screen's Share button, not this sheet.
struct NewPlanView: View {
    let current: TrainingPlan
    /// A plan shared to Dromo from another app, read straight away.
    let sharedText: String?
    let onReplace: (TrainingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    /// What Dromo read, or the problems that stopped it. At most one of the two at a time.
    @State private var newPlan: TrainingPlan?
    @State private var problems: [String] = []
    @State private var hasCopiedPrompt = false
    @State private var isChoosingFile = false

    var body: some View {
        NavigationStack {
            Form {
                // A shared plan is already here; asking the chat is for starting from scratch.
                if sharedText == nil {
                    askSection
                    pasteSection
                }
                if let newPlan {
                    summary(of: newPlan)
                    sessions(of: newPlan)
                }
                if !problems.isEmpty {
                    problemsSection
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        replace()
                    } label: {
                        Text("Replace").foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentFill)
                    .disabled(newPlan == nil)
                }
            }
            .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json, .plainText]) { outcome in
                readChosenFile(outcome)
            }
            .task {
                if let sharedText {
                    read(sharedText)
                }
            }
        }
    }

    // MARK: - Sections

    private var askSection: some View {
        Section {
            // A plain copy rather than a share sheet, so no second sheet opens over this one.
            Button("Copy AI Prompt", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = PlanFormat.prompt(today: .today)
                hasCopiedPrompt = true
            }
        } footer: {
            Text(promptNote)
        }
    }

    private var pasteSection: some View {
        Section {
            // The system paste button reads the clipboard without iOS asking for permission first.
            PasteButton(payloadType: String.self) { strings in
                read(strings.first ?? "")
            }
            Button("Choose File", systemImage: "doc") {
                isChoosingFile = true
            }
        } footer: {
            Text("Then copy the chat's reply and paste it here, or choose the file it made.")
        }
    }

    private func summary(of plan: TrainingPlan) -> some View {
        Section {
            LabeledContent("Plan", value: plan.title)
            if let race = plan.race {
                LabeledContent("Race", value: "\(race.name) · \(DistanceText.race(race.distanceMeters)) · \(race.date.shortText)")
            }
            LabeledContent("Sessions", value: "\(plan.workouts.count) in \(CountText.weeks(plan.weeks.count))")
            if let first = plan.workouts.first, let last = plan.workouts.last {
                LabeledContent("Dates", value: "\(first.date.dayMonthText) – \(last.date.dayMonthText)")
            }
        } header: {
            Text("New Plan")
        } footer: {
            Text(replaceNote(for: plan))
        }
    }

    /// Each session as it will look in the plan, so a wrong day or a missing session shows before it's too late.
    private func sessions(of plan: TrainingPlan) -> some View {
        ForEach(plan.weeks) { week in
            Section(week.title) {
                ForEach(week.workouts) { workout in
                    WorkoutRow(workout: workout, status: .upcoming)
                }
            }
        }
        .environment(\.paceScale, plan.paceScale)
    }

    private var problemsSection: some View {
        Section {
            // By position: two problems can read the same.
            ForEach(problems.indices, id: \.self) { index in
                Text(problems[index])
            }
            Button("Copy Problems", systemImage: "doc.on.doc") {
                copyProblems()
            }
        } header: {
            Text("Couldn't Read This Plan")
        } footer: {
            Text("Paste the problems into your chat and ask for the corrected plan.")
        }
    }

    private var promptNote: String {
        if hasCopiedPrompt {
            return "Copied. Paste it into your AI chat and describe the plan you want."
        }
        return "Paste it into your AI chat and describe the plan you want. To change your current plan instead, share it with the chat from the plan screen."
    }

    private func replaceNote(for plan: TrainingPlan) -> String {
        var note = "Replaces “\(current.title)” and any edits you made to it. Days that stay in the plan keep their done marks, and you can undo straight after."
        if let last = plan.workouts.last, last.date < .today {
            note += " Every session in this plan is in the past."
        }
        return note
    }

    // MARK: - Actions

    private func read(_ text: String) {
        do throws(PlanFile.Problems) {
            newPlan = try PlanFile.read(text)
            problems = []
        } catch {
            newPlan = nil
            problems = error.messages
        }
    }

    private func readChosenFile(_ outcome: Result<URL, any Error>) {
        guard case .success(let url) = outcome, let text = Self.text(of: url) else {
            newPlan = nil
            problems = ["Dromo couldn't open that file. Choose the .json or text file the plan is in."]
            return
        }
        read(text)
    }

    /// The problems as a message to paste back into the chat.
    private func copyProblems() {
        var message = "Dromo couldn't read the plan:\n"
        for problem in problems {
            message += "- \(problem)\n"
        }
        message += "Please send the whole corrected plan."
        UIPasteboard.general.string = message
    }

    private func replace() {
        guard let newPlan else { return }
        onReplace(newPlan)
        dismiss()
    }

    /// A file's text. Files from the picker or another app can be security-scoped: open them only while reading.
    static func text(of url: URL) -> String? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

#Preview {
    NewPlanView(current: BundledPlan.plan, sharedText: nil) { _ in }
}
