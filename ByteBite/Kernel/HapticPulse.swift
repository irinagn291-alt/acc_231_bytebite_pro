import UIKit

/// HapticPulse fires only on a successful commit. Navigation stays silent.
enum HapticPulse {
    @MainActor
    static func commit() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
