import SwiftUI

/// The top of a session: what and when, how long, and where it stands.
struct WorkoutHeader: View {
    let workout: PlannedWorkout
    let status: WorkoutStatus

    @Environment(\.paceScale) private var paceScale

    private var type: SessionType { SessionType(workout) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveStack(spacing: 12) {
                SessionBadge(type, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLine.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(type.name)
                        .font(.subheadline.weight(.semibold))
                }
                // Wrap rather than truncate when stacked at accessibility sizes.
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(workout.title)
                .font(.display(.largeTitle))

            AdaptiveStack(alignment: .firstTextBaseline, spacing: 24) {
                MetricView(title: "Time", value: "≈ \(DurationText.approximate(workout.estimatedSeconds(on: paceScale)))")
                MetricView(title: "Distance", value: "≈ \(DistanceText.kilometers(workout.estimatedMeters(on: paceScale)))")
                if pacedSeconds > 0 {
                    MetricView(title: "At pace", value: DurationText.approximate(pacedSeconds))
                }
            }

            AdaptiveStack(spacing: 8) {
                Chip(title: status.title, systemImage: status.symbol ?? "calendar", tint: status.tint)
                if workout.isCheckpoint {
                    Chip(title: "Checkpoint", systemImage: "flag.checkered", tint: .effortInk)
                }
            }
        }
    }

    /// "Thursday 1 October", with the start time on race day.
    private var dateLine: String {
        if let start = workout.startTime {
            return "\(workout.date.longText) · \(start.text)"
        }
        return workout.date.longText
    }

    /// Time spent held to a Watch pace alert.
    private var pacedSeconds: Int {
        workout.timeline.filter(\.kind.enforcesPace).map { $0.estimatedSeconds(on: paceScale) }.reduce(0, +)
    }
}
