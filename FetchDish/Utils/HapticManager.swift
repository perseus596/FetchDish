import SwiftUI

#if canImport(UIKit)
import UIKit

enum HapticManager {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
#else
// macOS — no haptics
enum HapticManager {
    static func light() {}
    static func medium() {}
    static func success() {}
    static func selection() {}
}
#endif
