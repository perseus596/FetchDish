import Foundation
import SwiftUI

// On macOS, system font defaults are too small for large displays (body = 13pt).
// These constants bump sizes up to be comfortable on 24"+ monitors.
// On iOS they map directly to Dynamic Type semantic styles.
extension Font {
    #if os(macOS)
    static let appBody        = Font.system(size: 15)
    static let appHeadline    = Font.system(size: 16, weight: .semibold)
    static let appSubheadline = Font.system(size: 14)
    static let appCallout     = Font.system(size: 15)
    static let appFootnote    = Font.system(size: 13)
    static let appCaption     = Font.system(size: 13)
    static let appCaption2    = Font.system(size: 12)
    #else
    static let appBody        = Font.body
    static let appHeadline    = Font.headline
    static let appSubheadline = Font.subheadline
    static let appCallout     = Font.callout
    static let appFootnote    = Font.footnote
    static let appCaption     = Font.caption
    static let appCaption2    = Font.caption2
    #endif
}

extension Array {
    /// Split array into chunks of a given size.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
