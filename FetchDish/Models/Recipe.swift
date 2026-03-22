import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID
    var title: String
    var descriptionText: String?
    var sourceUrl: String?
    @Attribute(.externalStorage) var imageData: Data?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var servings: Int?
    @Relationship(deleteRule: .cascade) var ingredients: [RecipeIngredient]
    @Relationship(deleteRule: .cascade) var instructions: [RecipeInstruction]
    var notes: String?
    var tagsRaw: String = ""
    var calories: String?
    var fat: String?
    var carbs: String?
    var protein: String?
    var fiber: String?
    var sugar: String?
    var cuisine: String?
    var mood: String?
    var dateAdded: Date
    var dateModified: Date
    var isFavorite: Bool
    var dietaryTagsRaw: String = ""

    @Transient
    var tags: [String] {
        get { tagsRaw.isEmpty ? [] : tagsRaw.components(separatedBy: ",") }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    @Transient
    var dietaryTags: [String] {
        get { dietaryTagsRaw.isEmpty ? [] : dietaryTagsRaw.components(separatedBy: ",") }
        set { dietaryTagsRaw = newValue.joined(separator: ",") }
    }

    init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil,
        sourceUrl: String? = nil,
        imageData: Data? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil,
        totalTime: String? = nil,
        servings: Int? = nil,
        ingredients: [RecipeIngredient] = [],
        instructions: [RecipeInstruction] = [],
        notes: String? = nil,
        tags: [String] = [],
        calories: String? = nil,
        fat: String? = nil,
        carbs: String? = nil,
        protein: String? = nil,
        fiber: String? = nil,
        sugar: String? = nil,
        cuisine: String? = nil,
        mood: String? = nil,
        dateAdded: Date = Date(),
        dateModified: Date = Date(),
        isFavorite: Bool = false,
        dietaryTags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.sourceUrl = sourceUrl
        self.imageData = imageData
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.notes = notes
        self.tagsRaw = tags.joined(separator: ",")
        self.calories = calories
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
        self.fiber = fiber
        self.sugar = sugar
        self.cuisine = cuisine
        self.mood = mood
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.isFavorite = isFavorite
        self.dietaryTagsRaw = dietaryTags.joined(separator: ",")
    }
}

@Model
final class RecipeIngredient {
    var id: UUID
    var original: String
    var amount: Double?
    var unit: String?
    var name: String?
    var isChecked: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        original: String,
        amount: Double? = nil,
        unit: String? = nil,
        name: String? = nil,
        isChecked: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.original = original
        self.amount = amount
        self.unit = unit
        self.name = name
        self.isChecked = isChecked
        self.sortOrder = sortOrder
    }
}

@Model
final class RecipeInstruction {
    var id: UUID
    var stepNumber: Int
    var text: String
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        stepNumber: Int,
        text: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.text = text
        self.isCompleted = isCompleted
    }
}
