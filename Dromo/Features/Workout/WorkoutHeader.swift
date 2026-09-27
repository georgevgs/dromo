import SwiftUI

/// The top of a session: what and when, how long, and where it stands.
struct WorkoutHeader: View {
    let workout: PlannedWorkout
    let status: WorkoutStatus

    private var type: SessionType { SessionType(workout) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SessionBadge(type, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLine.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(type.name)
                        .font(.subheadline.weight(.semibold))
                }
            }

            Text(workout.title)
                .font(.display(.largeTitle, weight: .heavy))

            AdaptiveStack(alignment: .firstTextBaseline, spacing: 24) {
                MetricView(title: "Time", value: "≈ \(DurationText.approximate(workout.estimatedSeconds))")
                MetricView(title: "Distance", value: "≈ \(DistanceText.kilometers(workout.estimatedMeters))")
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
        workout.startTime.map { "\(workout.date.longText) · \($0.text)" } ?? workout.date.longText
    }

    /// Time spent held to a Watch pace alert.
    private var pacedSeconds: Int {
        workout.timeline.filter(\.kind.enforcesPace).map(\.estimatedSeconds).reduce(0, +)
    }
}
