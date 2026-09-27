import SwiftUI

extension EnvironmentValues {
    /// The current plan's pace scale, for time and distance estimates and effort bars. Set once at the root.
    @Entry var paceScale = PaceScale.standard
}
