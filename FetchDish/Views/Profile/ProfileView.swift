import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @Query(sort: \FavoriteIngredient.name) private var favoriteIngredients: [FavoriteIngredient]
    @Query(sort: \UserAllergen.name) private var allergens: [UserAllergen]
    @Query(sort: \UserDietaryPreference.name) private var dietaryPrefs: [UserDietaryPreference]

    private let fetchDishURL = URL(string: "https://fetchdish.com")

    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("cookModeFontSize") private var cookModeFontSize: Double = 1.4
    @AppStorage("appFontScale") private var appFontScale: Double = 1.0
    @State private var hasSeeded = false

    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showClearConfirm = false
    @State private var showProUpgrade = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var exportData: Data?
    @State private var exportFormat: ExportFormat = .txt
    @State private var newFavoriteIngredient = ""
    @State private var newCustomAllergen = ""
    @State private var showOnboarding = false

    enum ExportFormat {
        case txt, rtf, pdf

        var contentType: UTType {
            switch self {
            case .txt: return .plainText
            case .rtf: return .rtf
            case .pdf: return .pdf
            }
        }

        var fileExtension: String {
            switch self {
            case .txt: return "txt"
            case .rtf: return "rtf"
            case .pdf: return "pdf"
            }
        }

        var displayName: String {
            switch self {
            case .txt: return "Text (.txt)"
            case .rtf: return "Rich Text (.rtf)"
            case .pdf: return "PDF"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                favoriteIngredientsSection
                allergiesDietarySection
                appearanceSection
                textSizeSection
                cookModeSection
                dataSection
                subscriptionSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background { profileBackground }
        .navigationTitle("Profile")
        .onAppear { seedDefaultsIfNeeded() }
        .confirmationDialog(
            "This will permanently delete all recipes and shopping list items.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                clearAllData()
            }
        }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeSheet()
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: GenericExportDocument(data: exportData ?? Data(), contentType: exportFormat.contentType),
            contentType: exportFormat.contentType,
            defaultFilename: "fetchdish-recipes-\(dateString()).\(exportFormat.fileExtension)"
        ) { result in
            switch result {
            case .success:
                toastMessage = "Recipes exported!"
                showToast = true
                HapticManager.success()
            case .failure:
                toastMessage = "Export failed."
                showToast = true
            }
        }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.plainText, .rtf, .pdf, .data]
        ) { result in
            switch result {
            case .success(let url):
                importRecipes(from: url)
            case .failure:
                toastMessage = "Import failed."
                showToast = true
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
                    .padding(.bottom, 100)
            }
        }
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - Background

    private var profileBackground: some View {
        ZStack {
            Image("ProfileShelvesBackground")
                .resizable()
                .scaledToFill()
            Color.black.opacity(0.15)
        }
        #if os(iOS)
        .ignoresSafeArea()
        #endif
    }

    // MARK: - Favorite Ingredients

    private var favoriteIngredientsSection: some View {
        ProfileSection(title: "Favorite Ingredients", footer: "Quick-fill these in \"What Can I Cook?\" with one tap.") {
            VStack(spacing: 0) {
                ForEach(favoriteIngredients) { ingredient in
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color("Terracotta"))
                            .font(.caption)
                        Text(ingredient.name)
                        Spacer()
                        Text(ingredient.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if ingredient.id != favoriteIngredients.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }

                Divider().padding(.leading, 16)

                HStack {
                    TextField("Add ingredient...", text: $newFavoriteIngredient)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    Button {
                        addFavoriteIngredient()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color("AccentGreen"))
                    }
                    .disabled(newFavoriteIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Allergies & Dietary

    private var allergiesDietarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ALLERGIES & DIETARY")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                allergiesContent
                Divider().overlay(.white.opacity(0.2))
                dietaryContent
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
    }

    private var allergiesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color("Terracotta"))
                    .font(.subheadline)
                Text("Allergies")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            FlowLayoutProfile(spacing: 8) {
                ForEach(allergens) { allergen in
                    AllergenChipButton(allergen: allergen, modelContext: modelContext)
                }
            }

            HStack {
                TextField("Add custom allergen...", text: $newCustomAllergen)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                Button {
                    addCustomAllergen()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color("AccentGreen"))
                }
                .disabled(newCustomAllergen.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("Active allergens show warning badges on recipe cards.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var dietaryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color("AccentGreen"))
                    .font(.subheadline)
                Text("Dietary Preferences")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            FlowLayoutProfile(spacing: 8) {
                ForEach(dietaryPrefs) { pref in
                    DietaryChipButton(pref: pref, modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        ProfileSection(title: "Appearance") {
            HStack {
                Text("Theme")
                Spacer()
                Picker("", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.segmented)
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Text Size

    private var textSizeSection: some View {
        ProfileSection(title: "Text Size", footer: "Adjusts font size across the entire app.") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text(appFontScale < 1.15 ? "Normal" :
                         appFontScale < 1.35 ? "Large" :
                         appFontScale < 1.55 ? "Larger" :
                         appFontScale < 1.75 ? "Extra Large" : "Maximum")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $appFontScale, in: 1.0...2.0, step: 0.1)
                    .tint(Color("AccentGreen"))
                Text("The quick brown fox jumps over the lazy dog.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Cook Mode

    private var cookModeSection: some View {
        ProfileSection(title: "Cook Mode", footer: "Adjust font size when Cook Mode is active.") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text(String(format: "%.1f×", cookModeFontSize))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $cookModeFontSize, in: 1.0...2.0, step: 0.1)
                    .tint(Color("AccentGreen"))
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.system(size: 16 * cookModeFontSize))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        ProfileSection(title: "Data") {
            VStack(spacing: 0) {
                Menu {
                    Button { exportRecipes(format: .txt) } label: {
                        Label("Text (.txt)", systemImage: "doc.plaintext")
                    }
                    Button { exportRecipes(format: .rtf) } label: {
                        Label("Rich Text (.rtf)", systemImage: "doc.richtext")
                    }
                    Button { exportRecipes(format: .pdf) } label: {
                        Label("PDF", systemImage: "doc.fill")
                    }
                } label: {
                    Label("Export All Recipes", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .disabled(recipes.isEmpty)

                Divider().padding(.leading, 16)

                Button { showImportSheet = true } label: {
                    Label("Import Recipes", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                }

                Divider().padding(.leading, 16)

                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label("Clear All Data", systemImage: "trash")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        ProfileSection(title: "Subscription") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProStatus.isPro ? "FetchDish Pro" : "FetchDish Free")
                        .font(.headline)
                    Text(ProStatus.isPro
                         ? "Unlimited recipes, full export, multiple lists."
                         : "\(recipes.count)/\(ProStatus.freeRecipeLimit) recipes used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !ProStatus.isPro {
                    Button {
                        showProUpgrade = true
                    } label: {
                        Text("Upgrade")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color("AccentGreen"))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color("AccentGreen"))
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        ProfileSection(title: "About") {
            VStack(spacing: 0) {
                Button {
                    showOnboarding = true
                } label: {
                    HStack {
                        Label("View App Tutorial", systemImage: "book.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Recipes Saved")
                    Spacer()
                    Text("\(recipes.count)").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().padding(.leading, 16)

                if let fetchDishURL {
                    Link(destination: fetchDishURL) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    Divider().padding(.leading, 16)
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        #else
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
            .frame(minWidth: 1000, minHeight: 750)
        }
        #endif
    }

    // MARK: - Seeding

    private func seedDefaultsIfNeeded() {
        guard !hasSeeded else { return }
        hasSeeded = true
        if allergens.isEmpty {
            let defaults = ["Nuts", "Dairy", "Gluten", "Shellfish", "Soy", "Eggs", "Fish", "Wheat", "Sesame"]
            for name in defaults {
                modelContext.insert(UserAllergen(name: name, isActive: false))
            }
            try? modelContext.save()
        }
        let allDefaults = [
            "Vegan", "Vegetarian", "Pescatarian", "Plant-Based",
            "Keto", "Paleo", "Whole30", "Low-Carb", "Mediterranean",
            "Gluten-Free", "Dairy-Free", "Nut-Free", "Sugar-Free",
            "Halal", "Kosher", "Carnivore", "Raw Food", "Other"
        ]
        let existingNames = Set(dietaryPrefs.map { $0.name })
        let missing = allDefaults.filter { !existingNames.contains($0) }
        if !missing.isEmpty {
            for name in missing {
                modelContext.insert(UserDietaryPreference(name: name, isActive: false))
            }
            try? modelContext.save()
        }
    }

    // MARK: - Favorite Ingredients

    private func addFavoriteIngredient() {
        let name = newFavoriteIngredient.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let category = IngredientCategorizer.categorize(name)
        modelContext.insert(FavoriteIngredient(name: name, category: category))
        try? modelContext.save()
        newFavoriteIngredient = ""
        HapticManager.success()
    }

    // MARK: - Custom Allergens

    private func addCustomAllergen() {
        let name = newCustomAllergen.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(UserAllergen(name: name, isActive: true))
        try? modelContext.save()
        newCustomAllergen = ""
        HapticManager.success()
    }

    // MARK: - Data Actions

    private func exportRecipes(format: ExportFormat) {
        exportFormat = format

        let data: Data?
        switch format {
        case .txt:
            let textString = ExportImportService.exportRecipesAsText(recipes)
            data = textString.data(using: .utf8)
        case .rtf:
            data = ExportImportService.exportRecipesAsRichText(recipes)
        case .pdf:
            data = ExportImportService.exportRecipesAsPDF(recipes)
        }

        if let data = data {
            exportData = data
            showExportSheet = true
        } else {
            toastMessage = "Export failed to generate file."
            showToast = true
        }
    }

    private func importRecipes(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let fileExtension = url.pathExtension
            let count = try ExportImportService.importRecipes(from: data, fileExtension: fileExtension, into: modelContext)
            toastMessage = "Imported \(count) recipe\(count == 1 ? "" : "s")!"
            showToast = true
            HapticManager.success()
        } catch {
            toastMessage = "Import failed: \(error.localizedDescription)"
            showToast = true
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: Recipe.self)
            try modelContext.delete(model: ShoppingListItem.self)
            try modelContext.delete(model: FavoriteIngredient.self)
            try modelContext.delete(model: UserAllergen.self)
            try modelContext.delete(model: UserDietaryPreference.self)
            try modelContext.save()
            toastMessage = "All data cleared."
            showToast = true
        } catch {
            toastMessage = "Failed to clear data."
            showToast = true
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Chip Buttons (extracted to fix type-check complexity)

private struct AllergenChipButton: View {
    let allergen: UserAllergen
    let modelContext: ModelContext

    var body: some View {
        Button {
            allergen.isActive.toggle()
            try? modelContext.save()
        } label: {
            Text(allergen.name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    ZStack {
                        Capsule()
                            .fill(allergen.isActive ? Color("Terracotta") : .white.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(allergen.isActive ? 0.2 : 0.1), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Capsule()
                            .strokeBorder(.white.opacity(allergen.isActive ? 0.3 : 0.2), lineWidth: 0.6)
                    }
                }
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct DietaryChipButton: View {
    let pref: UserDietaryPreference
    let modelContext: ModelContext

    var body: some View {
        Button {
            pref.isActive.toggle()
            try? modelContext.save()
        } label: {
            Text(pref.name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    ZStack {
                        Capsule()
                            .fill(pref.isActive ? Color("AccentGreen") : .white.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(pref.isActive ? 0.2 : 0.1), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Capsule()
                            .strokeBorder(.white.opacity(pref.isActive ? 0.3 : 0.2), lineWidth: 0.6)
                    }
                }
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Section Card

private struct ProfileSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            if let footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Flow Layout for chips

struct FlowLayoutProfile: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        return CGSize(width: containerWidth, height: y + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}
