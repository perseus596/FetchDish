import Foundation
import SwiftData

@Model
final class ShoppingListItem {
    var id: UUID
    var ingredient: String
    var recipeId: UUID
    var recipeName: String
    var isChecked: Bool
    var category: String

    init(
        id: UUID = UUID(),
        ingredient: String,
        recipeId: UUID,
        recipeName: String,
        isChecked: Bool = false,
        category: String = "other"
    ) {
        self.id = id
        self.ingredient = ingredient
        self.recipeId = recipeId
        self.recipeName = recipeName
        self.isChecked = isChecked
        self.category = category
    }
}
