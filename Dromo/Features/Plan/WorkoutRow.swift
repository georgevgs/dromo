import SwiftUI

/// One session in the week list.
struct WorkoutRow: View {
    let workout: PlannedWorkout
    let status: WorkoutStatus

    @Environment(\.paceScale) private var paceScale

    private var isToday: Bool { workout.date == .today }

    var body: some View {
        HStack(spacing: 12) {
            // At accessibility sizes the badge goes above the text, so titles keep the row's width.
            AdaptiveStack(spacing: 12) {
                SessionBadge(SessionType(workout))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(workout.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(titleStyle)
                        if workout.isCheckpoint {
                            Image(systemName: "flag.checkered")
                                .font(.caption)
                                .foregroundStyle(.effortInk)
                                .accessibilityLabel("Fitness checkpoint")
                        }
                    }
                    // Today's line stands out in the accent colour.
                    if isToday {
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    } else {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)
            StatusIcon(status: status)
        }
        .accessibilityElement(children: .combine)
    }

    /// Missed sessions step back.
    private var titleStyle: HierarchicalShapeStyle {
        if status == .missed {
            return .secondary
        }
        return .primary
    }

    /// "Today · 36 min", "Thu 1 Oct · 45 min", "Sat 7 Nov · 17:00"
    private var subtitle: String {
        let day = workout.date.relativeText()
        let detail = workout.startTime?.text ?? DurationText.approximate(workout.estimatedSeconds(on: paceScale))
        return "\(day) · \(detail)"
    }
}
