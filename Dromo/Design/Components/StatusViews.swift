import SwiftUI

/// A session's status as a trailing symbol in a row. Nothing for sessions still to come.
struct StatusIcon: View {
    let status: WorkoutStatus

    var body: some View {
        if let symbol = status.symbol {
            Image(systemName: symbol)
                .foregroundStyle(status.tint)
                .accessibilityLabel(status.title)
        }
    }
}

/// A small tinted capsule: a status, the checkpoint flag, a pace alert.
struct Chip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: .capsule)
    }
}
