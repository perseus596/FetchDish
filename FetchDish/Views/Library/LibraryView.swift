import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.dateAdded, order: .reverse) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var selectedSort: SortOption = .dateAdded
    @State private var selectedTag: String?
    @State private var selectedCuisine: String?
    @State private var showDeleteConfirm = false
    @State private var recipeToDelete: Recipe?
    @State private var isEditing = false
    @AppStorage("appearance") private var appearance: String = "system"

    private var isDark: Bool { appearance == "dark" }

    enum SortOption: String, CaseIterable {
        case dateAdded = "Newest"
        case alphabetical = "A-Z"
        case cookTime = "Cook Time"
    }

    private var recipesPerRow: Int { 3 }

    private var filteredRecipes: [Recipe] {
        var result = recipes

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { recipe in
                recipe.title.lowercased().contains(query)
                || recipe.ingredients.contains { $0.original.lowercased().contains(query) }
                || recipe.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Tag filter
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Cuisine filter
        if let cuisine = selectedCuisine {
            result = result.filter { $0.cuisine == cuisine }
        }

        // Sort
        switch selectedSort {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .alphabetical:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .cookTime:
            result.sort { ($0.cookTime ?? "zzz") < ($1.cookTime ?? "zzz") }
        }

        return result
    }

    private var allTags: [String] {
        Array(Set(recipes.flatMap { $0.tags })).sorted()
    }

    private var availableCuisines: [String] {
        Array(Set(recipes.compactMap { $0.cuisine })).sorted()
    }

    var body: some View {
        Group {
            if recipes.isEmpty {
                emptyState
            } else {
                shelfLibrary
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toolbarMenu
            }
            ToolbarItem(placement: .navigation) {
                if !recipes.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isEditing.toggle()
                        }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .fontWeight(isEditing ? .semibold : .regular)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search recipes or ingredients")
        .confirmationDialog(
            "Delete \(recipeToDelete?.title ?? "this recipe")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let recipe = recipeToDelete {
                    withAnimation {
                        modelContext.delete(recipe)
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
        Menu {
            Picker("Sort", selection: $selectedSort) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Divider()

            if !availableCuisines.isEmpty {
                Menu("Filter by Cuisine") {
                    Button("All Cuisines") { selectedCuisine = nil }
                    ForEach(availableCuisines, id: \.self) { cuisine in
                        Button {
                            selectedCuisine = cuisine
                        } label: {
                            HStack {
                                Text(cuisine)
                                if selectedCuisine == cuisine {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if !allTags.isEmpty {
                Menu("Filter by Tag") {
                    Button("All Tags") { selectedTag = nil }
                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            selectedTag = tag
                        } label: {
                            HStack {
                                Text(tag)
                                if selectedTag == tag {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("AccentGreen").opacity(0.5))

            Text("No recipes yet")
                .font(.title3.bold())

            Text("Import a recipe from any URL or add one manually to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shelf Library

    private var shelfBackground: Color {
        isDark ? Color(red: 0.15, green: 0.13, blue: 0.10) : Color(red: 0.94, green: 0.90, blue: 0.83)
    }

    private var shelfLibrary: some View {
        ScrollView {
            libraryHeader

            LazyVStack(spacing: 20) {
                let rows = filteredRecipes.chunked(into: recipesPerRow)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, rowRecipes in
                    ShelfRowView(
                        recipes: rowRecipes,
                        maxPerRow: recipesPerRow,
                        isEditing: isEditing,
                        onDelete: { recipe in
                            recipeToDelete = recipe
                            showDeleteConfirm = true
                        }
                    )
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 100)
        }
        .scrollContentBackground(.hidden)
        .background(
            shelfBackground
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        #if os(iOS)
        .toolbarBackground(shelfBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #elseif os(macOS)
        .toolbarBackground(shelfBackground, for: .windowToolbar)
        .toolbarColorScheme(.light, for: .windowToolbar)
        #endif
    }

    // MARK: - Library Header

    private var libraryHeader: some View {
        HStack {
            Text("\(filteredRecipes.count) recipe\(filteredRecipes.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let tag = selectedTag {
                filterChip(label: tag) { selectedTag = nil }
            }
            if let cuisine = selectedCuisine {
                filterChip(label: cuisine) { selectedCuisine = nil }
            }

            Spacer()

            if !ProStatus.isPro {
                Text("\(recipes.count)/\(ProStatus.freeRecipeLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color("AccentGreen").opacity(0.2))
            .clipShape(Capsule())
        }
        .tint(Color("AccentGreen"))
    }
}
