import SwiftUI

/// A small caption over a rounded number, as in Apple Fitness.
struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.rounded(.title3))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
