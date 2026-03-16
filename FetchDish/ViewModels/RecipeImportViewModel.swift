import Foundation
import SwiftData
import SwiftUI

/// Manages the URL import flow: fetching, parsing, previewing, and saving.
@Observable
final class RecipeImportViewModel {
    var urlText: String = ""
    var isLoading: Bool = false
    var loadingMessage: String = ""
    var errorMessage: String?
    var parsedRecipe: RecipeParser.ParsedRecipe?
    var showPreview: Bool = false

    private let parser = RecipeParser()
    private var loadingTimer: Timer?

    private let loadingMessages = [
        "Skipping the life story...",
        "Dodging the pop-ups...",
        "Extracting the good stuff...",
        "Filtering out the ads...",
        "Finding the actual recipe...",
        "Ignoring the SEO paragraphs...",
        "Scrolling past the vacation photos...",
        "Almost there...",
    ]

    // MARK: - Import

    @MainActor
    func importRecipe() async {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            errorMessage = "Paste a recipe URL first."
            return
        }

        // Basic URL validation
        var finalUrl = url
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            finalUrl = "https://\(url)"
        }

        guard URL(string: finalUrl) != nil else {
            errorMessage = "That doesn't look like a valid URL. Check it and try again."
            return
        }

        isLoading = true
        errorMessage = nil
        parsedRecipe = nil
        startLoadingMessages()

        do {
            let recipe = try await parser.fetchAndParse(url: finalUrl)
            parsedRecipe = recipe
            showPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }

        stopLoadingMessages()
        isLoading = false
    }

    /// Save the parsed recipe into SwiftData.
    @MainActor
    func saveRecipe(context: ModelContext, title: String? = nil) async -> Recipe? {
        guard let parsed = parsedRecipe else { return nil }

        let recipe = Recipe(
            title: title ?? parsed.title,
            descriptionText: parsed.description,
            sourceUrl: parsed.sourceUrl,
            prepTime: parsed.prepTime,
            cookTime: parsed.cookTime,
            totalTime: parsed.totalTime,
            servings: parsed.servings,
            ingredients: parsed.ingredients.enumerated().map { index, ing in
                RecipeIngredient(
                    original: ing.original,
                    amount: ing.amount,
                    unit: ing.unit,
                    name: ing.name,
                    sortOrder: index
                )
            },
            instructions: parsed.instructions.map { inst in
                RecipeInstruction(stepNumber: inst.stepNumber, text: inst.text)
            },
            calories: parsed.calories,
            fat: parsed.fat,
            carbs: parsed.carbs,
            protein: parsed.protein,
            fiber: parsed.fiber,
            sugar: parsed.sugar,
            cuisine: parsed.cuisine
        )

        // Fetch and store image data
        if let imageUrl = parsed.imageUrl {
            recipe.imageData = await parser.fetchImageData(url: imageUrl)
        }

        context.insert(recipe)
        try? context.save()

        // Reset state
        urlText = ""
        parsedRecipe = nil
        showPreview = false

        return recipe
    }

    // MARK: - Loading messages

    private func startLoadingMessages() {
        var index = 0
        loadingMessage = loadingMessages[0]
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            index = (index + 1) % self.loadingMessages.count
            Task { @MainActor in
                self.loadingMessage = self.loadingMessages[index]
            }
        }
    }

    private func stopLoadingMessages() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }

    func reset() {
        urlText = ""
        isLoading = false
        errorMessage = nil
        parsedRecipe = nil
        showPreview = false
        stopLoadingMessages()
    }
}
