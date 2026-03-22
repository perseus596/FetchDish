import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recipeId: UUID
    @Binding var navigationPath: NavigationPath

    @AppStorage("cookModeFontSize") private var cookModeFontSize: Double = 1.4
    @State private var recipe: Recipe?
    @State private var cookMode = false
    @State private var activeStep: Int? = nil
    @State private var servingMultiplier: Double = 1.0
    @State private var showShareSheet = false
    @State private var showAddToShopping = false
    @State private var showDeleteConfirm = false
    @State private var toastMessage = ""
    @State private var showToast = false

    @State private var shoppingVM = ShoppingListViewModel()
    @State private var showGoToShoppingList = false
    @State private var showCookModeTip = false
    @AppStorage("hasSeenCookModeTip") private var hasSeenCookModeTip = false
    #if os(macOS)
    @State private var showConverter = false
    #endif
    #if canImport(UIKit)
    @State private var decodedImage: UIImage?
    #else
    @State private var decodedImage: NSImage?
    #endif

    var body: some View {
        Group {
            if let recipe {
                recipeContent(recipe)
            } else {
                ContentUnavailableView("Recipe not found", systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear {
            loadRecipe()
            if !hasSeenCookModeTip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showCookModeTip = true
                    hasSeenCookModeTip = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        showCookModeTip = false
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func recipeContent(_ recipe: Recipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageData = recipe.imageData {
                    recipeImage(imageData)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(recipe.title)
                        .font(cookMode ? .system(size: 24 * cookModeFontSize, weight: .bold) : .title2.bold())
                        .padding(.horizontal)

                    // Description
                    if let desc = recipe.descriptionText, !desc.isEmpty, !cookMode {
                        Text(desc)
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    // Meta badges
                    if recipe.prepTime != nil || recipe.cookTime != nil || recipe.totalTime != nil || recipe.servings != nil {
                        metaBadges(recipe)
                    }

                    // Serving adjuster
                    if recipe.servings != nil {
                        ServingAdjusterView(
                            originalServings: recipe.servings!,
                            multiplier: $servingMultiplier
                        )
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // Ingredients
                    if !recipe.ingredients.isEmpty {
                        ingredientSection(recipe)
                    }

                    Divider().padding(.horizontal)

                    // Instructions
                    if !recipe.instructions.isEmpty {
                        instructionSection(recipe)
                    }

                    // Nutrition
                    if !cookMode, recipe.calories != nil || recipe.protein != nil {
                        nutritionSection(recipe)
                    }

                    // Notes
                    if let notes = recipe.notes, !notes.isEmpty, !cookMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.appHeadline)
                                .padding(.horizontal)
                            Text(notes)
                                .font(.appBody)
                                .padding(.horizontal)
                        }
                    }

                    // Dietary tags
                    if !cookMode {
                        dietarySection(recipe)
                    }

                    // Tags
                    if !recipe.tags.isEmpty, !cookMode {
                        FlowLayout(spacing: 8) {
                            ForEach(recipe.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.appCaption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("AccentGreen").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Source
                    if let url = recipe.sourceUrl, let linkUrl = URL(string: url), !cookMode {
                        Link(destination: linkUrl) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.appCaption)
                                Text("View Original")
                                    .font(.appCaption)
                            }
                            .foregroundStyle(Color("AccentGreen"))
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                #if os(macOS)
                // Unit converter
                Button {
                    showConverter.toggle()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "scalemass")
                        Text("Convert")
                            .font(.system(size: 9))
                    }
                }
                .popover(isPresented: $showConverter, arrowEdge: .top) {
                    UnitConverterView()
                }
                #endif

                // Cook mode toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cookMode.toggle()
                    }
                    if cookMode {
                        #if canImport(UIKit)
                        UIApplication.shared.isIdleTimerDisabled = true
                        #endif
                    } else {
                        #if canImport(UIKit)
                        UIApplication.shared.isIdleTimerDisabled = false
                        #endif
                        activeStep = nil
                    }
                    HapticManager.medium()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: cookMode ? "flame.fill" : "flame")
                        Text(cookMode ? "Cooking" : "Cook")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(cookMode ? Color("Terracotta") : .primary)
                }
                .popover(isPresented: $showCookModeTip, arrowEdge: .top) {
                    Text("**Cook Mode** — keeps your screen on and enlarges text while you cook")
                        .font(.appSubheadline)
                        .padding()
                        .frame(width: 220)
                        .presentationCompactAdaptation(.popover)
                }

                // Actions menu
                Menu {
                    Menu("Share as...") {
                        Button {
                            shareRecipe(format: .text)
                        } label: {
                            Label("Text", systemImage: "doc.text")
                        }
                        
                        Button {
                            shareRecipe(format: .pdf)
                        } label: {
                            Label("PDF", systemImage: "doc.fill")
                        }
                    }

                    Button {
                        shoppingVM.addRecipeToShoppingList(recipe: recipe, context: modelContext)
                        toastMessage = "Added to shopping list!"
                        showToast = true
                        HapticManager.success()
                    } label: {
                        Label("Add to Shopping List", systemImage: "cart.badge.plus")
                    }

                    Button {
                        recipe.isFavorite.toggle()
                        try? modelContext.save()
                        HapticManager.light()
                    } label: {
                        Label(
                            recipe.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: recipe.isFavorite ? "heart.slash" : "heart"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete \(recipe.title)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(recipe)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This recipe will be permanently removed.")
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
        .onDisappear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }

    // MARK: - Data Loading

    private func loadRecipe() {
        let targetId = recipeId
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == targetId }
        )
        let fetched = try? modelContext.fetch(descriptor).first
        recipe = fetched

        // Decode image off the main thread to avoid blocking the UI
        if let imageData = fetched?.imageData {
            Task.detached(priority: .userInitiated) {
                #if canImport(UIKit)
                let image = UIImage(data: imageData)
                #else
                let image = NSImage(data: imageData)
                #endif
                await MainActor.run {
                    decodedImage = image
                }
            }
        }
    }

    // MARK: - Subviews

    enum ShareFormat {
        case text, pdf
    }
    
    private func shareRecipe(format: ShareFormat) {
        let text = ExportImportService.recipeAsText(recipe!, servingMultiplier: servingMultiplier)
        
        #if canImport(UIKit)
        var itemsToShare: [Any] = []
        
        switch format {
        case .text:
            itemsToShare = [text]
        case .pdf:
            if let pdfData = ExportImportService.exportRecipesAsPDF([recipe!]) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe!.title).pdf")
                try? pdfData.write(to: tempURL)
                itemsToShare = [tempURL]
            } else {
                itemsToShare = [text]
            }
        }
        
        let ac = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(ac, animated: true)
        }
        #else
        // macOS
        switch format {
        case .text:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            toastMessage = "Copied to clipboard!"
            showToast = true
        case .pdf:
            if let pdfData = ExportImportService.exportRecipesAsPDF([recipe!]) {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.pdf]
                savePanel.nameFieldStringValue = "\(recipe!.title).pdf"
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        try? pdfData.write(to: url)
                        toastMessage = "PDF saved!"
                        showToast = true
                    }
                }
            } else {
                toastMessage = "PDF export is not available on macOS."
                showToast = true
            }
        }
        #endif
    }

    @ViewBuilder
    private func recipeImage(_ data: Data) -> some View {
        if !cookMode {
            GeometryReader { geo in
                #if canImport(UIKit)
                if let uiImage = decodedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 250)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color("AccentGreen").opacity(0.15))
                        .frame(width: geo.size.width, height: 250)
                }
                #else
                if let nsImage = decodedImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 250)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color("AccentGreen").opacity(0.15))
                        .frame(width: geo.size.width, height: 250)
                }
                #endif
            }
            .frame(height: 250)
        }
    }

    private func metaBadges(_ recipe: Recipe) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let prep = recipe.prepTime {
                    MetaBadge(icon: "clock", label: "Prep", value: prep)
                }
                if let cook = recipe.cookTime {
                    MetaBadge(icon: "flame", label: "Cook", value: cook)
                }
                if let total = recipe.totalTime {
                    MetaBadge(icon: "timer", label: "Total", value: total)
                }
                if let servings = recipe.servings {
                    let adjusted = Int(Double(servings) * servingMultiplier)
                    MetaBadge(icon: "person.2", label: "Serves", value: "\(adjusted)")
                }
            }
            .padding(.horizontal)
        }
    }

    private func ingredientSection(_ recipe: Recipe) -> some View {
        let checkedIngredients = recipe.ingredients.filter { $0.isChecked }

        let allChecked = recipe.ingredients.allSatisfy { $0.isChecked }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ingredients")
                    .font(cookMode ? .system(size: 18 * cookModeFontSize, weight: .bold) : .appHeadline)
                Spacer()
                if !cookMode {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let newValue = !allChecked
                            for ingredient in recipe.ingredients {
                                ingredient.isChecked = newValue
                            }
                            try? modelContext.save()
                        }
                        HapticManager.selection()
                    } label: {
                        Text(allChecked ? "Deselect All" : "Select All")
                            .font(.appSubheadline)
                            .foregroundStyle(Color("AccentGreen"))
                    }
                }
            }
            .padding(.horizontal)

            ForEach(recipe.ingredients.sorted(by: { $0.sortOrder < $1.sortOrder })) { ingredient in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        ingredient.isChecked.toggle()
                        try? modelContext.save()
                    }
                    HapticManager.selection()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: ingredient.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(ingredient.isChecked ? Color("AccentGreen") : .secondary)
                            .font(.appBody)

                        Text(ingredientDisplayText(ingredient))
                            .font(cookMode ? .system(size: 16 * cookModeFontSize) : .appBody)
                            .strikethrough(ingredient.isChecked)
                            .opacity(ingredient.isChecked ? 0.5 : 1)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // Add checked ingredients to shopping list
            if !checkedIngredients.isEmpty && !cookMode && !showGoToShoppingList {
                Button {
                    let count = checkedIngredients.count
                    for ingredient in checkedIngredients {
                        let item = ShoppingListItem(
                            ingredient: ingredient.original,
                            recipeId: recipe.id,
                            recipeName: recipe.title,
                            category: IngredientCategorizer.categorize(ingredient.original)
                        )
                        modelContext.insert(item)
                        ingredient.isChecked = false
                    }
                    try? modelContext.save()
                    toastMessage = "Added \(count) item\(count == 1 ? "" : "s") to shopping list"
                    showToast = true
                    withAnimation { showGoToShoppingList = true }
                    HapticManager.success()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.badge.plus")
                        Text("Add \(checkedIngredients.count) to Shopping List")
                    }
                    .font(.appSubheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("AccentGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Go back to shopping list after adding
            if showGoToShoppingList && !cookMode {
                Button {
                    navigationPath = NavigationPath()
                    navigationPath.append(AppDestination.shoppingList)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                        Text("Go back to Shopping List")
                    }
                    .font(.appSubheadline.bold())
                    .foregroundStyle(Color("AccentGreen"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("AccentGreen").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func ingredientDisplayText(_ ingredient: RecipeIngredient) -> AttributedString {
        if servingMultiplier != 1.0 {
            let text = IngredientParser.scaledText(ingredient: ingredient, multiplier: servingMultiplier)
            return AttributedString(text)
        }

        // Bold the amount and unit
        var result = AttributedString()
        if let amount = ingredient.amount {
            var amountStr = AttributedString(IngredientParser.scale(amount: amount, by: 1.0))
            amountStr.font = .appBody.bold()
            result.append(amountStr)
            result.append(AttributedString(" "))
        }
        if let unit = ingredient.unit {
            var unitStr = AttributedString(unit)
            unitStr.font = .appBody.bold()
            result.append(unitStr)
            result.append(AttributedString(" "))
        }
        if let name = ingredient.name {
            result.append(AttributedString(name))
        } else if ingredient.amount == nil && ingredient.unit == nil {
            result = AttributedString(ingredient.original)
        }
        return result
    }

    private func instructionSection(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Instructions")
                .font(cookMode ? .system(size: 18 * cookModeFontSize, weight: .bold) : .appHeadline)
                .padding(.horizontal)

            ForEach(recipe.instructions.sorted(by: { $0.stepNumber < $1.stepNumber })) { instruction in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if activeStep == instruction.stepNumber {
                            activeStep = nil
                            instruction.isCompleted = true
                        } else {
                            activeStep = instruction.stepNumber
                        }
                        try? modelContext.save()
                    }
                    HapticManager.selection()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(instruction.stepNumber)")
                            .font(.appCaption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                activeStep == instruction.stepNumber
                                    ? Color("AccentGreen")
                                    : instruction.isCompleted
                                        ? Color.gray
                                        : Color("AccentGreen").opacity(0.4)
                            )
                            .clipShape(Circle())

                        Text(instruction.text)
                            .font(cookMode ? .system(size: 16 * cookModeFontSize) : .appBody)
                            .multilineTextAlignment(.leading)
                            .opacity(instruction.isCompleted ? 0.5 : 1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        activeStep == instruction.stepNumber
                            ? Color("AccentGreen").opacity(0.08)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    static let dietaryOptions = [
        "Vegan", "Vegetarian", "Pescatarian", "Plant-Based",
        "Keto", "Paleo", "Whole30", "Low-Carb", "Mediterranean",
        "Gluten-Free", "Dairy-Free", "Nut-Free", "Sugar-Free",
        "Halal", "Kosher", "Carnivore", "Raw Food", "Other"
    ]

    private func dietarySection(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dietary")
                .font(.appHeadline)
                .padding(.horizontal)

            FlowLayout(spacing: 6) {
                ForEach(Self.dietaryOptions, id: \.self) { option in
                    let isTagged = recipe.dietaryTags.contains(option)
                    Button {
                        if isTagged {
                            recipe.dietaryTags.removeAll { $0 == option }
                        } else {
                            recipe.dietaryTags.append(option)
                        }
                        try? modelContext.save()
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 4) {
                            if isTagged {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(option)
                                .font(.appCaption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isTagged ? Color("AccentGreen") : Color("AccentGreen").opacity(0.1))
                        .foregroundStyle(isTagged ? .white : Color("AccentGreen"))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color("AccentGreen").opacity(0.35), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func nutritionSection(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition")
                .font(.appHeadline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                if let cal = recipe.calories {
                    NutritionBadge(label: "Cal", value: cal)
                }
                if let protein = recipe.protein {
                    NutritionBadge(label: "Protein", value: protein)
                }
                if let carbs = recipe.carbs {
                    NutritionBadge(label: "Carbs", value: carbs)
                }
                if let fat = recipe.fat {
                    NutritionBadge(label: "Fat", value: fat)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

struct NutritionBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.appCaption.bold())
            Text(label)
                .font(.appCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ServingAdjusterView: View {
    let originalServings: Int
    @Binding var multiplier: Double

    private var displayServings: Int {
        max(1, Int((Double(originalServings) * multiplier).rounded()))
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("Servings")
                .font(.appSubheadline.weight(.medium))

            Spacer()

            Button {
                let newServings = max(1, displayServings - 1)
                multiplier = Double(newServings) / Double(originalServings)
                HapticManager.light()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color("AccentGreen"))
            }
            .disabled(displayServings <= 1)

            Text("\(displayServings)")
                .font(.title3.bold())
                .frame(minWidth: 32)

            Button {
                let newServings = displayServings + 1
                multiplier = Double(newServings) / Double(originalServings)
                HapticManager.light()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color("AccentGreen"))
            }

            if multiplier != 1.0 {
                Button {
                    multiplier = 1.0
                    HapticManager.light()
                } label: {
                    Text("Reset")
                        .font(.appCaption)
                        .foregroundStyle(Color("Terracotta"))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Unit Converter (macOS Pro feature)

#if os(macOS)
struct UnitConverterView: View {
    enum CUnit: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case g = "g", oz = "oz", lb = "lb", kg = "kg"
        case tsp = "tsp", tbsp = "tbsp", floz = "fl oz", cup = "cup"
        case ml = "ml", l = "l", pt = "pt", qt = "qt", gal = "gal"

        var isWeight: Bool { [.g, .oz, .lb, .kg].contains(self) }

        var toBase: Double {
            switch self {
            case .g:    return 1.0
            case .oz:   return 28.3495
            case .lb:   return 453.592
            case .kg:   return 1000.0
            case .tsp:  return 4.92892
            case .tbsp: return 14.7868
            case .floz: return 29.5735
            case .cup:  return 236.588
            case .ml:   return 1.0
            case .l:    return 1000.0
            case .pt:   return 473.176
            case .qt:   return 946.353
            case .gal:  return 3785.41
            }
        }
    }

    static let weightUnits: [CUnit] = [.g, .oz, .lb, .kg]
    static let volumeUnits: [CUnit] = [.tsp, .tbsp, .floz, .cup, .ml, .l, .pt, .qt, .gal]

    @State private var inputText = "1"
    @State private var fromUnit: CUnit = .cup
    @State private var toUnit: CUnit = .ml
    @State private var showProUpgrade = false

    private var canConvert: Bool { fromUnit.isWeight == toUnit.isWeight }

    private var result: String {
        guard canConvert, let value = Double(inputText), value >= 0 else { return "—" }
        let converted = value * fromUnit.toBase / toUnit.toBase
        if converted == 0 { return "0" }
        if converted >= 100 { return String(format: "%.1f", converted) }
        if converted >= 1  { return String(format: "%.2f", converted) }
        return String(format: "%.4f", converted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(Color("Terracotta"))
                    .font(.title3)
                Text("Unit Converter")
                    .font(.appHeadline)
                Spacer()
                Label("Pro", systemImage: "star.fill")
                    .font(.appCaption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color("Terracotta"))
                    .clipShape(Capsule())
            }

            if !ProStatus.isPro {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color("Terracotta").opacity(0.6))
                    Text("Unit Converter is a Pro feature.")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showProUpgrade = true
                    } label: {
                        Text("Upgrade to Pro")
                            .font(.appSubheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color("AccentGreen"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .sheet(isPresented: $showProUpgrade) {
                    ProUpgradeSheet()
                }
            } else {
                // Input row
                HStack(spacing: 10) {
                    TextField("Amount", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Picker("From", selection: $fromUnit) {
                        Section("Weight") {
                            ForEach(Self.weightUnits) { u in Text(u.rawValue).tag(u) }
                        }
                        Section("Volume") {
                            ForEach(Self.volumeUnits) { u in Text(u.rawValue).tag(u) }
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90)

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    Picker("To", selection: $toUnit) {
                        Section("Weight") {
                            ForEach(Self.weightUnits) { u in Text(u.rawValue).tag(u) }
                        }
                        Section("Volume") {
                            ForEach(Self.volumeUnits) { u in Text(u.rawValue).tag(u) }
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }

                // Result
                VStack(spacing: 6) {
                    Text(canConvert ? result : "—")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(canConvert ? Color("AccentGreen") : Color("Terracotta"))
                        .frame(maxWidth: .infinity)

                    if canConvert, let value = Double(inputText) {
                        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
                            ? String(Int(value)) : String(format: "%.2f", value)
                        Text("\(formatted) \(fromUnit.rawValue)  =  \(result) \(toUnit.rawValue)")
                            .font(.appCallout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    } else if !canConvert {
                        Text("Can't convert between weight and volume")
                            .font(.appCaption)
                            .foregroundStyle(Color("Terracotta"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
#endif

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth && lineWidth > 0 {
                height += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
