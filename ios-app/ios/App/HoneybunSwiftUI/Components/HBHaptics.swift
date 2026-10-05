import UIKit

// Quiet haptics for the moments that matter (an entry saved, deleted, restored, a bill paid). Never for navigation or taps that just move around.
@MainActor enum HBHaptics {
    /// something was saved or completed
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// something was deleted (the Undo button is right there)
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    /// a gentle tap: Undo, restore, saved-for-later
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
