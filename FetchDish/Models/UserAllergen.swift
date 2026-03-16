import Foundation
import SwiftData

@Model
final class UserAllergen {
    var id: UUID
    var name: String
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}
