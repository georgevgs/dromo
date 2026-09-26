import SwiftUI

/// The next session to run: what it is, its shape, how long it takes and whether it's on the Watch.
struct UpNextCard: View {
    let workout: PlannedWorkout
    let status: WorkoutStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SessionBadge(SessionType(workout), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(when.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(workout.date == .today ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(workout.title)
                        .font(.display(.title3))
                }
                Spacer(minLength: 0)
                StatusIcon(status: status)
                    .font(.title3)
            }

            StructureChart(workout: workout, height: 40)

            AdaptiveStack(spacing: 16) {
                Label("≈ \(DurationText.approximate(workout.estimatedSeconds))", systemImage: "clock")
                Label("≈ \(DistanceText.kilometers(workout.estimatedMeters))", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    /// "Today", "Tomorrow", "Thu 1 Oct" — with the start time when it matters.
    private var when: String {
        let day = workout.date.relativeText()
        return workout.startTime.map { "\(day) · \($0.text)" } ?? day
    }
}
