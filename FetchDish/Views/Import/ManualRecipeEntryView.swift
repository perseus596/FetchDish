import SwiftUI
import SwiftData
import PhotosUI

struct ManualRecipeEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var recipes: [Recipe]

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var servingsText = ""
    @State private var ingredientsText = ""
    @State private var instructionsText = ""
    @State private var notes = ""
    @State private var tagsText = ""
    @State private var selectedCuisine = ""
    @State private var selectedMood = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showUpgradePrompt = false
    @State private var proManager = ProManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // Photo
                Section {
                    if let imageData, let uiImage = platformImage(from: imageData) {
                        imageView(uiImage)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                imageData = data
                            }
                        }
                    }
                }

                // Basic info
                Section("Basic Info") {
                    TextField("Recipe Title *", text: $title)
                        .font(.headline)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Timing
                Section("Timing") {
                    TextField("Prep Time (e.g. 15 min)", text: $prepTime)
                    TextField("Cook Time (e.g. 30 min)", text: $cookTime)
                    TextField("Servings (e.g. 4)", text: $servingsText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }

                // Ingredients
                Section {
                    TextField("Enter ingredients, one per line", text: $ingredientsText, axis: .vertical)
                        .lineLimit(5...20)
                        .font(.body)
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text("One ingredient per line. Example:\n2 cups flour\n1 tsp salt\n3 eggs")
                        .font(.caption)
                }

                // Instructions
                Section {
                    TextField("Enter instructions, one step per line", text: $instructionsText, axis: .vertical)
                        .lineLimit(5...20)
                        .font(.body)
                } header: {
                    Text("Instructions")
                } footer: {
                    Text("One step per line. They'll be numbered automatically.")
                        .font(.caption)
                }

                // Notes & Tags
                Section("Notes & Tags") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Tags (comma-separated)", text: $tagsText)
                }

                // Classification
                Section("Classification") {
                    Picker("Cuisine", selection: $selectedCuisine) {
                        Text("None").tag("")
                        ForEach(RecipeCuisine.allCases) { cuisine in
                            Text("\(cuisine.icon) \(cuisine.rawValue)").tag(cuisine.rawValue)
                        }
                    }
                    Picker("Mood", selection: $selectedMood) {
                        Text("None").tag("")
                        ForEach(RecipeMood.allCases) { mood in
                            Text("\(mood.icon) \(mood.rawValue)").tag(mood.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Add Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .fontWeight(.semibold)
                        .tint(Color("AccentGreen"))
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showUpgradePrompt) {
                UpgradePromptView(triggerMessage: "You've reached the 5-recipe limit.")
            }
        }
    }

    private func saveRecipe() {
        // Check Pro limit
        if !proManager.canSaveMoreRecipes(currentCount: recipes.count) {
            showUpgradePrompt = true
            return
        }

        let ingredients = ingredientsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, line in
                let parsed = IngredientParser.parse(line)
                return RecipeIngredient(
                    original: line,
                    amount: parsed.amount,
                    unit: parsed.unit,
                    name: parsed.name,
                    sortOrder: index
                )
            }

        let instructions = instructionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, line in
                RecipeInstruction(stepNumber: index + 1, text: line)
            }

        let tags = tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let recipe = Recipe(
            title: title.trimmingCharacters(in: .whitespaces),
            descriptionText: descriptionText.isEmpty ? nil : descriptionText,
            imageData: imageData,
            prepTime: prepTime.isEmpty ? nil : prepTime,
            cookTime: cookTime.isEmpty ? nil : cookTime,
            servings: Int(servingsText),
            ingredients: ingredients,
            instructions: instructions,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            cuisine: selectedCuisine.isEmpty ? nil : selectedCuisine,
            mood: selectedMood.isEmpty ? nil : selectedMood
        )

        modelContext.insert(recipe)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }

    // MARK: - Platform helpers

    #if canImport(UIKit)
    private func platformImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }

    private func imageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }
    #else
    private func platformImage(from data: Data) -> NSImage? {
        NSImage(data: data)
    }

    private func imageView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
    }
    #endif
}
