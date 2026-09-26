import SwiftUI

/// One session in the week list.
struct WorkoutRow: View {
    let workout: PlannedWorkout
    let status: WorkoutStatus

    private var isToday: Bool { workout.date == .today }

    var body: some View {
        HStack(spacing: 12) {
            SessionBadge(SessionType(workout))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(workout.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(status == .missed ? .secondary : .primary)
                    if workout.isCheckpoint {
                        Image(systemName: "flag.checkered")
                            .font(.caption)
                            .foregroundStyle(.effortInk)
                            .accessibilityLabel("Fitness checkpoint")
                    }
                }
                Text(subtitle)
                    .font(.subheadline.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }

            Spacer(minLength: 8)
            StatusIcon(status: status)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Today · 36 min", "Thu 1 Oct · 45 min", "Sat 7 Nov · 17:00"
    private var subtitle: String {
        let day = workout.date.relativeText()
        let detail = workout.startTime?.text ?? DurationText.approximate(workout.estimatedSeconds)
        return "\(day) · \(detail)"
    }
}
