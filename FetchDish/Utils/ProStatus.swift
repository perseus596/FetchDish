import Foundation
import SwiftUI

/// Manages the Pro upgrade status.
/// Free tier: 25 recipes. Pro: unlimited.
/// For now, Pro is a simple UserDefaults flag (payment integration comes later).
enum ProStatus {
    static let freeRecipeLimit = 25

    static var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "isPro") }
        set { UserDefaults.standard.set(newValue, forKey: "isPro") }
    }

    static func canSaveMore(currentCount: Int) -> Bool {
        isPro || currentCount < freeRecipeLimit
    }

    /// Unlock Pro (placeholder — will connect to StoreKit later).
    static func unlockPro() {
        isPro = true
    }
}
