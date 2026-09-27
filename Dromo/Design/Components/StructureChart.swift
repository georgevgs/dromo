import SwiftUI

/// A session's shape at a glance: one bar per step, as wide as it lasts and as tall as it's hard,
/// in the same colours as the rest of the app.
struct StructureChart: View {
    let workout: PlannedWorkout
    var height: CGFloat = 48

    @Environment(\.paceScale) private var paceScale

    private struct Bar {
        let fraction: Double
        let intensity: Double
        let color: Color
    }

    var body: some View {
        let steps = workout.timeline
        let total = Double(max(steps.map { $0.estimatedSeconds(on: paceScale) }.reduce(0, +), 1))
        let bars = steps.map { step in
            Bar(fraction: Double(step.estimatedSeconds(on: paceScale)) / total, intensity: step.intensity(on: paceScale), color: step.kind.tint)
        }

        Canvas { context, size in
            // Thinner gaps once there are many bars, so the gaps don't eat the chart.
            var gap: CGFloat = 2
            if bars.count > 30 {
                gap = 1
            }
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
