import SwiftUI

/// The plan at a glance — countdown, goal and progress — under the night sky of the app icon.
/// A plan without a race counts down to its last session instead.
struct RaceHeader: View {
    let plan: TrainingPlan
    let progress: [[PlanProgress.Session]]

    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)

            countdown

            PlanProgress(weeks: progress)

            AdaptiveStack(alignment: .firstTextBaseline, spacing: 24) {
                if let race = plan.race, let goal = race.goalTimeSeconds, let pace = race.goalPaceSecondsPerKm {
                    MetricView(title: "Goal", value: DurationText.clock(goal))
                    MetricView(title: "Pace", value: "\(DurationText.minutesSeconds(pace))/km")
                } else {
                    MetricView(title: "Done", value: "\(doneCount) of \(plan.workouts.count)")
                }
                MetricView(title: week.title, value: week.value)
            }
        }
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        // Hierarchical styles such as .secondary resolve for the dark background in either appearance.
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var countdown: some View {
        let days = PlanDate.today.days(until: countdownDate)
        switch days {
        case 1...:
            AdaptiveStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(days, format: .number)
                    .font(.system(size: countdownSize, weight: .heavy).width(.expanded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(countdownLabel(days))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        default:
            Text(endLabel(days))
                .font(.system(size: countdownSize * 0.75, weight: .heavy).width(.expanded))
        }
    }

    /// Race day, or the last session when the plan has no race.
    private var countdownDate: PlanDate {
        if let race = plan.race {
            return race.date
        }
        if let last = plan.workouts.last {
            return last.date
        }
        return .today
    }

    /// "days to race", or "days to go" without one.
    private func countdownLabel(_ days: Int) -> String {
        var label = "days"
        if days == 1 {
            label = "day"
        }
        if plan.race == nil {
            return label + " to go"
        }
        return label + " to race"
    }

    /// "Race day" or "Last day" on the day itself, then "Finished".
    private func endLabel(_ days: Int) -> String {
        if days < 0 {
            return "Finished"
        }
        if plan.race == nil {
            return "Last day"
        }
        return "Race day"
    }

    /// "ATHENS · 5K · SAT 7 NOV · 17:00", or "6 WEEKS · ENDS SAT 7 NOV" without a race.
    private var eyebrow: String {
        guard let race = plan.race else {
            var parts = [CountText.weeks(plan.weeks.count)]
            if let last = plan.workouts.last {
                parts.append("ends \(last.date.shortText)")
            }
            return parts.joined(separator: " · ").uppercased()
        }
        var parts = [race.name, DistanceText.race(race.distanceMeters), race.date.shortText]
        if let start = plan.raceWorkout?.startTime {
            parts.append(start.text)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    private var doneCount: Int {
        progress.joined().filter { $0.status == .completed }.count
    }

    /// "Week 2 of 6", or when the plan starts.
    private var week: (title: String, value: String) {
        let started = plan.weeks.filter { week in
            guard let first = week.workouts.first else { return false }
            return first.date <= .today
        }.count
        if started == 0, let start = plan.workouts.first?.date {
            return ("Starts", start.dayMonthText)
        }
        return ("Week", "\(started) of \(plan.weeks.count)")
    }
}
