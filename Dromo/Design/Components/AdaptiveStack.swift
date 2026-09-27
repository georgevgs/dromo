import SwiftUI

/// A row that stacks vertically at accessibility text sizes, so side-by-side content never gets squeezed
/// into broken words (HIG, Layout: "horizontally adjacent views may need to stack vertically").
struct AdaptiveStack<Content: View>: View {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        layout { content }
    }

    /// AnyLayout rather than if/else, so the content keeps its identity when the text size changes.
    private var layout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        }
        return AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
    }
}
