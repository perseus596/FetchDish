import Foundation
import SwiftData

/// Shared ModelContainer factory used by both the main app and the Share Extension.
/// Uses App Groups so both processes read/write to the same SQLite database.
enum SharedModelContainer {
    static let appGroupID = "group.com.fetchdish.app"

    static func create() throws -> ModelContainer {
        let schema = Schema([
            Recipe.self,
            RecipeIngredient.self,
            RecipeInstruction.self,
            ShoppingListItem.self,
            FavoriteIngredient.self,
            UserAllergen.self,
            UserDietaryPreference.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [config])
    }
}
