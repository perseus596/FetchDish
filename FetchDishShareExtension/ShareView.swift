import SwiftUI
import SwiftData

/// The SwiftUI view presented inside the Share Extension.
/// Shows parsing progress, then a success/error state with recipe preview.
struct ShareView: View {
    let url: String?
    let extensionContext: NSExtensionContext?

    @State private var state: ShareState = .loading
    @State private var parsedRecipe: RecipeParser.ParsedRecipe?
    @State private var errorMessage: String?
    @State private var loadingMessage = "Skipping the life story..."

    private let parser = RecipeParser()

    private let modelContainer: ModelContainer? = {
        try? SharedModelContainer.create()
    }()

    enum ShareState {
        case loading
        case preview
        case saving
        case success
        case error
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    loadingView
                case .preview:
                    previewView
                case .saving:
                    savingView
                case .success:
                    successView
                case .error:
                    errorView
                }
            }
            .navigationTitle("FetchDish")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await parseRecipe()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)
            Text(loadingMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await cycleLoadingMessages()
        }
    }

    // MARK: - Preview

    private var previewView: some View {
        ScrollView {
            if let recipe = parsedRecipe {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(recipe.title)
                        .font(.title3.bold())
                        .padding(.horizontal)

                    // Time info
                    if recipe.prepTime != nil || recipe.cookTime != nil || recipe.servings != nil {
                        HStack(spacing: 12) {
                            if let prep = recipe.prepTime {
                                ShareBadge(icon: "clock", value: prep)
                            }
                            if let cook = recipe.cookTime {
                                ShareBadge(icon: "flame", value: cook)
                            }
                            if let servings = recipe.servings {
                                ShareBadge(icon: "person.2", value: "\(servings)")
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // Ingredient count
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.green)
                        Text("\(recipe.ingredients.count) ingredients")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "text.justify.left")
                            .foregroundStyle(.green)
                        Text("\(recipe.instructions.count) steps")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

                    // Save button
                    Button {
                        Task { await saveRecipe() }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Save to FetchDish")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.top)
            }
        }
    }

    // MARK: - Saving

    private var savingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Saving recipe...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Recipe Saved!")
                .font(.title3.bold())
            Text("Open FetchDish to view it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't import recipe")
                .font(.title3.bold())
            Text(errorMessage ?? "Try a different URL, or add the recipe manually in FetchDish.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func parseRecipe() async {
        guard let url, !url.isEmpty else {
            errorMessage = "No URL was shared."
            state = .error
            return
        }

        do {
            let recipe = try await parser.fetchAndParse(url: url)
            parsedRecipe = recipe
            state = .preview
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }

    @MainActor
    private func saveRecipe() async {
        guard let parsed = parsedRecipe, let container = modelContainer else {
            errorMessage = "Failed to save. Try opening FetchDish and importing manually."
            state = .error
            return
        }

        state = .saving

        let context = ModelContext(container)

        let recipe = Recipe(
            title: parsed.title,
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
            sugar: parsed.sugar
        )

        // Fetch image
        if let imageUrl = parsed.imageUrl {
            recipe.imageData = await parser.fetchImageData(url: imageUrl)
        }

        context.insert(recipe)

        do {
            try context.save()
            state = .success
        } catch {
            errorMessage = "Failed to save recipe: \(error.localizedDescription)"
            state = .error
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cycleLoadingMessages() async {
        let messages = [
            "Skipping the life story...",
            "Dodging the pop-ups...",
            "Extracting the good stuff...",
            "Filtering out the ads...",
            "Finding the actual recipe...",
        ]
        var index = 0
        while state == .loading {
            try? await Task.sleep(for: .seconds(1.5))
            index = (index + 1) % messages.count
            loadingMessage = messages[index]
        }
    }
}

// MARK: - Supporting Views

struct ShareBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.green)
            Text(value)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
