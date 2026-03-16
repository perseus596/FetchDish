import SwiftUI
import SwiftData

struct WhatCanICookView: View {
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query(sort: \FavoriteIngredient.name) private var favoriteIngredients: [FavoriteIngredient]

    @State private var selectedIngredients: Set<String> = []
    @State private var selectedCuisines: Set<String> = []
    @State private var selectedMoods: Set<String> = []
    @State private var searchText = ""
    @State private var showCategorized = false

    // MARK: - Computed Data

    private var allIngredientNames: [String] {
        let names = recipes.flatMap { $0.ingredients.compactMap { $0.name?.lowercased() } }
        return Array(Set(names)).sorted()
    }

    private var filteredIngredientNames: [String] {
        if searchText.isEmpty { return allIngredientNames }
        return allIngredientNames.filter { $0.contains(searchText.lowercased()) }
    }

    private var categorizedIngredients: [(String, [String])] {
        let grouped = Dictionary(grouping: filteredIngredientNames) { name in
            IngredientCategorizer.categorize(name)
        }
        // Use the defined display order so Meat and Seafood appear together
        return IngredientCategorizer.displayOrder.compactMap { category in
            guard let names = grouped[category], !names.isEmpty else { return nil }
            return (category, names)
        }
    }

    private var hasActiveFilters: Bool {
        !selectedIngredients.isEmpty || !selectedCuisines.isEmpty || !selectedMoods.isEmpty
    }

    private var matchingRecipes: [(recipe: Recipe, matchCount: Int, totalCount: Int)] {
        guard hasActiveFilters else { return [] }

        return recipes.compactMap { recipe in
            // Cuisine filter
            if !selectedCuisines.isEmpty {
                guard let cuisine = recipe.cuisine, selectedCuisines.contains(cuisine) else { return nil }
            }

            // Mood filter
            if !selectedMoods.isEmpty {
                guard let mood = recipe.mood, selectedMoods.contains(mood) else { return nil }
            }

            // Ingredient matching
            let recipeIngredientNames = Set(recipe.ingredients.compactMap { $0.name?.lowercased() })
            let totalCount = recipeIngredientNames.count

            if selectedIngredients.isEmpty {
                // Mood/cuisine only — show all that match
                return (recipe, totalCount, totalCount)
            } else {
                let matchCount = selectedIngredients.intersection(recipeIngredientNames).count
                guard matchCount > 0 else { return nil }
                return (recipe, matchCount, totalCount)
            }
        }
        .sorted { $0.matchCount > $1.matchCount }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recipes.isEmpty {
                    emptyState
                } else {
                    moodCuisineSelector
                    ingredientSelector
                    if hasActiveFilters {
                        resultsList
                    }
                }
                Spacer(minLength: 100)
            }
            .padding(.top)
        }
        .navigationTitle("What Can I Cook?")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "frying.pan")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No recipes yet")
                .font(.title3.bold())
            Text("Import some recipes first, then come back to find what you can cook!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Mood & Cuisine Selector

    private var moodCuisineSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What are you in the mood for?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            // Cuisine chips
            FlowLayout(spacing: 8) {
                ForEach(RecipeCuisine.allCases) { cuisine in
                    moodChip(
                        label: "\(cuisine.icon) \(cuisine.rawValue)",
                        isSelected: selectedCuisines.contains(cuisine.rawValue),
                        activeColor: Color("AccentGreen")
                    ) {
                        toggleInSet(&selectedCuisines, value: cuisine.rawValue)
                    }
                }
            }
            .padding(.horizontal)

            // Mood chips
            FlowLayout(spacing: 8) {
                ForEach(RecipeMood.allCases) { mood in
                    moodChip(
                        label: "\(mood.icon) \(mood.rawValue)",
                        isSelected: selectedMoods.contains(mood.rawValue),
                        activeColor: Color("Terracotta")
                    ) {
                        toggleInSet(&selectedMoods, value: mood.rawValue)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func moodChip(label: String, isSelected: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.selection()
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? activeColor : activeColor.opacity(0.12))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ingredient Selector

    private var ingredientSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select ingredients you have:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            // Search bar
            ingredientSearchBar

            // Quick actions + display toggle
            quickActionsBar

            // Ingredient chips (A-Z or Categorized)
            if showCategorized {
                categorizedIngredientsView
            } else {
                alphabeticalIngredientsView
            }
        }
    }

    private var ingredientSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search ingredients...", text: $searchText)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private var quickActionsBar: some View {
        HStack(spacing: 10) {
            if !favoriteIngredients.isEmpty {
                Button {
                    for fav in favoriteIngredients {
                        selectedIngredients.insert(fav.name.lowercased())
                    }
                    HapticManager.selection()
                } label: {
                    Label("Add Favorites", systemImage: "heart.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("AccentGreen").opacity(0.2))
                        .clipShape(Capsule())
                }
                .tint(Color("AccentGreen"))
            }

            if !selectedIngredients.isEmpty {
                Button {
                    selectedIngredients.removeAll()
                    HapticManager.selection()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("Terracotta").opacity(0.2))
                        .clipShape(Capsule())
                }
                .tint(Color("Terracotta"))
            }

            Spacer()

            // A-Z / Category toggle
            Button {
                showCategorized.toggle()
                HapticManager.selection()
            } label: {
                Label(
                    showCategorized ? "A-Z" : "By Category",
                    systemImage: showCategorized ? "textformat.abc" : "square.grid.2x2"
                )
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())
            }
            .tint(.blue)
        }
        .padding(.horizontal)
    }

    // MARK: - Alphabetical Ingredients

    private var alphabeticalIngredientsView: some View {
        FlowLayout(spacing: 8) {
            ForEach(filteredIngredientNames, id: \.self) { name in
                ingredientChip(name: name)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Categorized Ingredients

    private var categorizedIngredientsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(categorizedIngredients, id: \.0) { category, names in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    FlowLayout(spacing: 8) {
                        ForEach(names, id: \.self) { name in
                            ingredientChip(name: name)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Reusable Ingredient Chip

    private func ingredientChip(name: String) -> some View {
        Button {
            if selectedIngredients.contains(name) {
                selectedIngredients.remove(name)
            } else {
                selectedIngredients.insert(name)
            }
            HapticManager.selection()
        } label: {
            Text(name.capitalized)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    selectedIngredients.contains(name)
                        ? Color("AccentGreen")
                        : Color("AccentGreen").opacity(0.12)
                )
                .foregroundStyle(
                    selectedIngredients.contains(name) ? .white : .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.horizontal)

            Text("\(matchingRecipes.count) matching recipe\(matchingRecipes.count == 1 ? "" : "s")")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal)

            if matchingRecipes.isEmpty {
                noMatchesView
            } else {
                ForEach(matchingRecipes, id: \.recipe.id) { item in
                    NavigationLink(value: item.recipe.id) {
                        matchingRecipeRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private var noMatchesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No matches with these filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func matchingRecipeRow(item: (recipe: Recipe, matchCount: Int, totalCount: Int)) -> some View {
        HStack(spacing: 12) {
            recipeRowThumbnail(item.recipe)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.recipe.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !selectedIngredients.isEmpty {
                    Text("\(item.matchCount)/\(item.totalCount) ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color("AccentGreen").opacity(0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color("AccentGreen"))
                                .frame(width: geo.size.width * CGFloat(item.matchCount) / CGFloat(max(1, item.totalCount)))
                        }
                    }
                    .frame(height: 5)
                }

                if let cuisine = item.recipe.cuisine {
                    Text(cuisine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func recipeRowThumbnail(_ recipe: Recipe) -> some View {
        Group {
            if let imageData = recipe.imageData,
               let cgImage = platformImage(from: imageData) {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Color("AccentGreen").opacity(0.15)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Color("AccentGreen"))
                    }
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func toggleInSet(_ set: inout Set<String>, value: String) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    #if canImport(UIKit)
    private func platformImage(from data: Data) -> CGImage? {
        UIImage(data: data)?.cgImage
    }
    #else
    private func platformImage(from data: Data) -> CGImage? {
        NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    #endif
}
