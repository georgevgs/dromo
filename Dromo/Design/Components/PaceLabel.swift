import SwiftUI

/// A pace target. Watch pace alerts get a heat chip with a bell; guidance for easy running
/// is a quiet "≈" so it never reads as something to hit.
struct PaceLabel: View {
    let pace: PaceRange
    let isAlert: Bool

    var body: some View {
        if isAlert {
            Chip(title: pace.text, systemImage: "bell.fill", tint: .effortInk)
                .accessibilityLabel("Pace alert \(pace.text)")
        } else {
            Text("≈ \(pace.text)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
