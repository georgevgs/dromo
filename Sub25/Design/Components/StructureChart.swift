import SwiftUI

/// A session's shape at a glance: one bar per step, as wide as it lasts and as tall as it's hard,
/// in the same colours as the rest of the app.
struct StructureChart: View {
    let workout: PlannedWorkout
    var height: CGFloat = 48

    private struct Bar {
        let fraction: Double
        let intensity: Double
        let color: Color
    }

    var body: some View {
        let steps = workout.timeline
        let total = Double(max(steps.map(\.estimatedSeconds).reduce(0, +), 1))
        let bars = steps.map { step in
            Bar(fraction: Double(step.estimatedSeconds) / total, intensity: step.intensity, color: step.kind.tint)
        }

        Canvas { context, size in
            let gap: CGFloat = bars.count > 30 ? 1 : 2
            let usableWidth = size.width - gap * CGFloat(max(bars.count - 1, 0))
            var x: CGFloat = 0
            for bar in bars {
                let width = max(usableWidth * bar.fraction, 2)
                let barHeight = size.height * bar.intensity
                let rect = CGRect(x: x, y: size.height - barHeight, width: width, height: barHeight)
                let shape = Path(roundedRect: rect, cornerRadius: min(3, width / 2), style: .continuous)
                context.fill(shape, with: .color(bar.color))
                x += width + gap
            }
        }
        .frame(height: height)
        // Decorative: the step list reads out the same structure.
        .accessibilityHidden(true)
    }
}
