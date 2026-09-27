import SwiftUI

/// A session's type as a glowing neon disc with its symbol in night ink.
struct SessionBadge: View {
    let type: SessionType
    @ScaledMetric private var size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(_ type: SessionType, size: CGFloat = 32) {
        self.type = type
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.onTile)
            .frame(width: size, height: size)
            .background(type.tint.gradient, in: .circle)
            // Discs keep their neon (Dark Mode) colours in both appearances, so the night symbol keeps its contrast.
            .environment(\.colorScheme, .dark)
            .shadow(color: type.tint.opacity(colorScheme == .dark ? 0.55 : 0.3), radius: size * 0.25)
            .accessibilityHidden(true)
    }
}
