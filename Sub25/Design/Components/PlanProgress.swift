import SwiftUI

/// Every session in the plan as a capsule, grouped by week: done, missed, today or still to come.
/// Drawn for the dark race header.
struct PlanProgress: View {
    struct Session: Identifiable {
        let id: UUID
        let status: WorkoutStatus
        let isToday: Bool
    }

    let weeks: [[Session]]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weeks.indices, id: \.self) { week in
                HStack(spacing: 2) {
                    ForEach(weeks[week]) { session in
                        Capsule()
                            .fill(fill(for: session))
                            .overlay {
                                // Today is the one outlined capsule, so it doesn't rely on colour alone.
                                if session.isToday {
                                    Capsule().strokeBorder(.white, lineWidth: 1.5)
                                }
                            }
                            .frame(height: 7)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Plan progress")
        .accessibilityValue("\(doneCount) of \(weeks.joined().count) sessions done")
    }

    private var doneCount: Int {
        weeks.joined().filter { $0.status == .completed }.count
    }

    private func fill(for session: Session) -> Color {
        switch session.status {
        case .completed: .white
        case .missed: .white.opacity(0.35)
        case .upcoming, .onWatch: .white.opacity(0.16)
        }
    }
}
