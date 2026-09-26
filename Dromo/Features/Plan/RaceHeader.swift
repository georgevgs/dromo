import SwiftUI

/// The race at a glance — countdown, goal and progress through the plan — under the Golden Hour sky of the app icon.
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
                MetricView(title: "Goal", value: DurationText.minutesSeconds(plan.goalTimeSeconds))
                MetricView(title: "Pace", value: "\(DurationText.minutesSeconds(plan.goalPaceSecondsPerKm))/km")
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
        let days = PlanDate.today.days(until: plan.raceDate)
        switch days {
        case 1...:
            AdaptiveStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(days, format: .number)
                    .font(.system(size: countdownSize, weight: .heavy).width(.expanded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(days == 1 ? "day to race" : "days to race")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        default:
            Text(days == 0 ? "Race day" : "Finished")
                .font(.system(size: countdownSize * 0.75, weight: .heavy).width(.expanded))
        }
    }

    /// "ATHENS · 5K · SAT 7 NOV · 17:00"
    private var eyebrow: String {
        var parts = [plan.raceName, "\(plan.raceDistanceMeters / 1000)K", plan.raceDate.shortText]
        if let start = plan.raceWorkout?.startTime {
            parts.append(start.text)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    /// "Week 2 of 6", or when the plan starts.
    private var week: (title: String, value: String) {
        let started = plan.weeks.filter { ($0.workouts.first?.date ?? plan.raceDate) <= .today }.count
        if started == 0, let start = plan.workouts.first?.date {
            return ("Starts", start.dayMonthText)
        }
        return ("Week", "\(started) of \(plan.weeks.count)")
    }
}
