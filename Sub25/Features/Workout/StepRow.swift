import SwiftUI

/// One step of a session: its colour, how long, how it's run, and any pace.
struct StepRow: View {
    let segment: WorkoutSegment

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(segment.kind.tint)
                .frame(width: 4, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(segment.goal.text)
                    .font(.rounded(.headline))
                    .monospacedDigit()
                Text(segment.effortText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let pace = segment.pace {
                PaceLabel(pace: pace, isAlert: segment.kind.enforcesPace)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A block's header: "6 rounds" with a repeat symbol, or what a single pass is.
struct BlockHeader: View {
    let block: SegmentBlock

    var body: some View {
        if block.repeats > 1 {
            Label(block.title, systemImage: "repeat")
        } else {
            Text(block.title)
        }
    }
}
