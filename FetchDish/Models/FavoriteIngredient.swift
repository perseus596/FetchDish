import Foundation
import SwiftData

@Model
final class FavoriteIngredient {
    var id: UUID
    var name: String
    var category: String

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "Other"
    ) {
        self.id = id
        self.name = name
        self.category = category
    }
}
