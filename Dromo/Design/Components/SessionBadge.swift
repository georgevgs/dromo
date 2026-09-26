import SwiftUI

/// A session's type as a coloured tile with its symbol, in the style of the Settings app.
struct SessionBadge: View {
    let type: SessionType
    @ScaledMetric private var size: CGFloat

    init(_ type: SessionType, size: CGFloat = 32) {
        self.type = type
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(type.symbolColor)
            .frame(width: size, height: size)
            .background(type.tint.gradient, in: .rect(cornerRadius: size * 0.3, style: .continuous))
            // Like Settings icons, tiles keep their light colours in Dark Mode so the white symbol keeps its contrast.
            .environment(\.colorScheme, .light)
            .accessibilityHidden(true)
    }
}
