import SwiftUI
import SwiftData
import PhotosUI
#if canImport(AppKit)
import AppKit
#endif

@Observable
final class CookScrollState {
    var scrollOffset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var dragStartOffset: CGFloat = 0
    var autoScrollPlaying: Bool = false
    var autoScrollSpeed: Int = 2
    private var autoScrollTimer: Timer?

    private static let speedPoints: [CGFloat] = [0.5, 1.0, 1.8, 2.8, 4.0]

    func startAutoScroll() {
        stopAutoScroll()
        let safeIndex = max(0, min(autoScrollSpeed, Self.speedPoints.count - 1))
        let points = Self.speedPoints[safeIndex]
        let interval: TimeInterval = 1.0 / 60.0
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let maxOffset = max(0, self.contentHeight - self.viewportHeight)
            guard maxOffset > 0 else { return }
            var next = self.scrollOffset + points
            if next >= maxOffset { next = 0 }
            self.scrollOffset = next
        }
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    func reset() {
        scrollOffset = 0
        autoScrollPlaying = false
        stopAutoScroll()
    }
}

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recipeId: UUID
    @Binding var navigationPath: NavigationPath
    @Binding var isCookModeActive: Bool

    @AppStorage("cookModeFontSize") private var cookModeFontSize: Double = 1.4
    @State private var recipe: Recipe?
    @State private var cookMode = false
    @State private var activeStep: Int? = nil
    @State private var servingMultiplier: Double = 1.0
    @State private var showShareSheet = false
    @State private var showShareCard = false
    @State private var isRenderingCard = false
    @State private var showAddToShopping = false
    @State private var showDeleteConfirm = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var timerManager = CookTimerManager()

    @State private var shoppingVM = ShoppingListViewModel()
    @State private var showGoToShoppingList = false
    @State private var showCookModeTip = false
    @AppStorage("hasSeenCookModeTip") private var hasSeenCookModeTip = false
    @State private var showEditSheet = false
    @State private var showMyRecipeIntro = false
    @State private var showMyRecipeEdit = false
    @State private var introUserProceeded = false
    @State private var showProUpgradeForEdit = false
    @State private var showProUpgradeForMyRecipe = false
    @State private var ingredientsExpanded: Bool = true
    @State private var proManager = ProManager.shared
    #if os(macOS)
    @State private var showConverter = false
    #endif

    // MARK: - Safety alert state
    @State private var showSafetyAlert: Bool = false

    // MARK: - Auto-scroll state
    @State private var scrollState = CookScrollState()
    #if canImport(UIKit)
    @State private var decodedImage: UIImage?
    #else
    @State private var decodedImage: NSImage?
    #endif

    @ViewBuilder
    private var cookModeButton: some View {
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
                timerManager.removeAll()
                showSafetyAlert = true
            }
            HapticManager.medium()
        } label: {
            FlameIcon(cookMode: cookMode)
        }
        .popover(isPresented: $showCookModeTip, arrowEdge: .top) {
            Text("**Cook Mode** — keeps your screen on and enlarges text while you cook")
                .font(.appSubheadline)
                .padding()
                .frame(width: 220)
                .presentationCompactAdaptation(.popover)
        }
    }

    var body: some View {
        ZStack {
            Group {
                if let recipe {
                    recipeContent(recipe)
                } else {
                    ContentUnavailableView("Recipe not found", systemImage: "exclamationmark.triangle")
                }
            }

            // Timer sidebar lives at the outermost ZStack layer so it is
            // never clipped or zero-sized by the inner GeometryReader.
            // Visible in cook mode on both iOS and macOS.
            if cookMode, let recipe {
                CookModeTimerSidebar(recipe: recipe, timerManager: timerManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .allowsHitTesting(true)
                    .zIndex(999)
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

    // MARK: - Cook mode content builder (shared VStack body)
    @ViewBuilder
    private func recipeBodyContent(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageData = recipe.imageData {
                    recipeImage(imageData)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Title row with Edit / My Recipe buttons
                    HStack(alignment: .top, spacing: 8) {
                        Text(recipe.title)
                            .font(cookMode ? .system(size: 24 * cookModeFontSize, weight: .bold) : .title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !cookMode {
                            HStack(spacing: 6) {
                                // Edit button — sheet lives on this button so it is the sole
                                // sheet owner for this toggle state.
                                Button {
                                    if ProStatus.isPro {
                                        showEditSheet = true
                                    } else {
                                        showProUpgradeForEdit = true
                                    }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .font(.appCaption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color("AccentGreen").opacity(0.12))
                                        .foregroundStyle(Color("AccentGreen"))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                // Each sheet is attached to its own distinct view to avoid the
                                // SwiftUI bug where only the last chained .sheet on a single
                                // view is reliably presented.
                                .sheet(isPresented: $showEditSheet) {
                                    EditRecipeSheet(recipe: recipe, mode: .edit) { updatedDraft in
                                        recipe.title = updatedDraft.title
                                        recipe.servings = updatedDraft.servings
                                        recipe.prepTime = updatedDraft.prepTime.isEmpty ? recipe.prepTime : updatedDraft.prepTime
                                        recipe.cookTime = updatedDraft.cookTime.isEmpty ? recipe.cookTime : updatedDraft.cookTime
                                        recipe.totalTime = updatedDraft.totalTime.isEmpty ? recipe.totalTime : updatedDraft.totalTime
                                        recipe.notes = updatedDraft.notes
                                        recipe.imageData = updatedDraft.imageData
                                        // Sync ingredients
                                        let existing = recipe.ingredients
                                        for ing in existing { modelContext.delete(ing) }
                                        for (i, di) in updatedDraft.ingredients.enumerated() {
                                            let ing = RecipeIngredient(
                                                original: [di.amount, di.unit, di.name]
                                                    .compactMap { $0.isEmpty ? nil : $0 }.joined(separator: " "),
                                                amount: EditRecipeSheet.parseAmount(di.amount),
                                                unit: di.unit.isEmpty ? nil : di.unit,
                                                name: di.name.isEmpty ? nil : di.name,
                                                sortOrder: i
                                            )
                                            modelContext.insert(ing)
                                            recipe.ingredients.append(ing)
                                        }
                                        // Sync instructions
                                        let existingInstr = recipe.instructions
                                        for instr in existingInstr { modelContext.delete(instr) }
                                        for (i, text) in updatedDraft.instructions.enumerated() {
                                            let instr = RecipeInstruction(stepNumber: i + 1, text: text)
                                            modelContext.insert(instr)
                                            recipe.instructions.append(instr)
                                        }
                                        recipe.dateModified = Date()
                                        do {
                                            try modelContext.save()
                                        } catch {
                                            modelContext.rollback()
                                            print("Save error: \(error)")
                                        }
                                    }
                                }
                                .sheet(isPresented: $showProUpgradeForEdit) { ProUpgradeSheet() }

                                // My Recipe button — its two sheets (intro + copy editor) live
                                // here, each on a separate view so they don't conflict.
                                Button {
                                    if ProStatus.isPro {
                                        showMyRecipeIntro = true
                                    } else {
                                        showProUpgradeForMyRecipe = true
                                    }
                                } label: {
                                    Label("My Recipe", systemImage: "person.crop.rectangle")
                                        .font(.appCaption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color("Terracotta").opacity(0.12))
                                        .foregroundStyle(Color("Terracotta"))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showProUpgradeForMyRecipe) { ProUpgradeSheet() }

                                // showMyRecipeIntro lives on its own hidden anchor so it does
                                // not shadow showProUpgradeForMyRecipe on the same button node.
                                Color.clear
                                    .frame(width: 0, height: 0)
                                    .sheet(isPresented: $showMyRecipeIntro, onDismiss: {
                                        if introUserProceeded {
                                            introUserProceeded = false
                                            showMyRecipeEdit = true
                                        }
                                    }) {
                                        MyRecipeIntroSheet(originalTitle: recipe.title) {
                                            introUserProceeded = true
                                            showMyRecipeIntro = false
                                        }
                                    }

                                // The copy editor sheet lives on an independent hidden view so
                                // it does not share a sheet slot with any other button above.
                                Color.clear
                                    .frame(width: 0, height: 0)
                                    .sheet(isPresented: $showMyRecipeEdit) {
                                        EditRecipeSheet(recipe: recipe, mode: .copy) { draft in
                                            let originalTitle = recipe.title
                                            // Create brand new child objects
                                            let newIngredients = draft.ingredients.enumerated().map { (i, di) in
                                                RecipeIngredient(
                                                    original: [di.amount, di.unit, di.name]
                                                        .compactMap { $0.isEmpty ? nil : $0 }.joined(separator: " "),
                                                    amount: EditRecipeSheet.parseAmount(di.amount),
                                                    unit: di.unit.isEmpty ? nil : di.unit,
                                                    name: di.name.isEmpty ? nil : di.name,
                                                    sortOrder: i
                                                )
                                            }
                                            let newInstructions = draft.instructions.enumerated().map { (i, text) in
                                                RecipeInstruction(stepNumber: i + 1, text: text)
                                            }
                                            // Create a brand new Recipe — never touch the original
                                            let copy = Recipe(
                                                title: draft.title,
                                                descriptionText: recipe.descriptionText,
                                                sourceUrl: recipe.sourceUrl,
                                                imageData: draft.imageData,
                                                prepTime: draft.prepTime.isEmpty ? recipe.prepTime : draft.prepTime,
                                                cookTime: draft.cookTime.isEmpty ? recipe.cookTime : draft.cookTime,
                                                totalTime: draft.totalTime.isEmpty ? recipe.totalTime : draft.totalTime,
                                                servings: draft.servings,
                                                notes: draft.notes,
                                                tags: recipe.tags,
                                                cuisine: recipe.cuisine,
                                                mood: recipe.mood,
                                                dietaryTags: recipe.dietaryTags
                                            )
                                            // Insert the new Recipe first, then its children
                                            modelContext.insert(copy)
                                            for ing in newIngredients {
                                                modelContext.insert(ing)
                                                copy.ingredients.append(ing)
                                            }
                                            for ins in newInstructions {
                                                modelContext.insert(ins)
                                                copy.instructions.append(ins)
                                            }
                                            do { try modelContext.save() } catch { print("Save error: \(error)") }
                                            toastMessage = "\"My \(originalTitle)\" saved!"
                                            showToast = true
                                            HapticManager.success()
                                        }
                                    }
                            }
                        }
                    }
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
    } // recipeBodyContent

    @ViewBuilder
    private func recipeContent(_ recipe: Recipe) -> some View {
        GeometryReader { viewportGeo in
            if cookMode {
                // MARK: Cook mode — smooth pixel scrolling via .offset
                // Bug 1 fix: give the clipping container an explicit height matching the
                // viewport so SwiftUI's hit-test frame is the full visible area. Without a
                // height the frame collapses and swallows button taps inside the content.
                ZStack(alignment: .topTrailing) {
                    recipeBodyContent(recipe)
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .onAppear {
                                        scrollState.contentHeight = contentGeo.size.height
                                        scrollState.viewportHeight = viewportGeo.size.height
                                    }
                                    .onChange(of: contentGeo.size.height) { _, h in
                                        scrollState.contentHeight = h
                                    }
                            }
                        )
                        .offset(y: -scrollState.scrollOffset)
                        // Bug 1 fix: explicit width AND height so hit-testing covers the full
                        // viewport and inner Buttons receive taps correctly.
                        .frame(width: viewportGeo.size.width, height: viewportGeo.size.height, alignment: .top)
                        .clipped()
                        // Bug 1 fix: use simultaneousGesture for manual drag so it does NOT
                        // cancel tap gestures on child Button views.
                        // DragGesture.translation is cumulative from gesture start, so we
                        // capture dragStartScrollOffset on the first onChanged call (when
                        // the translation is still very small) and compute the new offset
                        // relative to that baseline on each subsequent call.
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    // Capture baseline when translation is near zero (gesture start)
                                    if abs(value.translation.height) <= 12 && abs(value.translation.width) <= 12 {
                                        scrollState.dragStartOffset = scrollState.scrollOffset
                                    }
                                    let maxOffset = max(0, scrollState.contentHeight - scrollState.viewportHeight)
                                    let next = (scrollState.dragStartOffset - value.translation.height)
                                        .clamped(to: 0...max(0, maxOffset))
                                    scrollState.scrollOffset = next
                                    // Do NOT pause auto-scroll — allow manual drag and auto-scroll simultaneously
                                }
                        )
                        .onAppear {
                            scrollState.viewportHeight = viewportGeo.size.height
                        }

                    // Bug 3 fix: custom scroll indicator — a thin bar on the right edge that
                    // reflects the current scroll position within the content.
                    // The indicator is interactive: dragging it scrolls the content directly.
                    CookModeScrollIndicator(
                        scrollOffset: Binding(get: { scrollState.scrollOffset }, set: { scrollState.scrollOffset = $0 }),
                        contentHeight: scrollState.contentHeight,
                        viewportHeight: viewportGeo.size.height
                    )
                }
            } else {
                // MARK: Normal mode — standard ScrollView
                ScrollView {
                    recipeBodyContent(recipe)
                }
                .scrollIndicators(.visible)
                .onAppear {
                    scrollState.viewportHeight = viewportGeo.size.height
                }
            }
        }
        .onChange(of: cookMode) { _, active in
            if !active { scrollState.reset() } else { scrollState.scrollOffset = 0 }
            isCookModeActive = active
        }
        .onChange(of: scrollState.autoScrollPlaying) { _, playing in
            if playing { scrollState.startAutoScroll() } else { scrollState.stopAutoScroll() }
        }
        .onChange(of: scrollState.autoScrollSpeed) { _, _ in
            if scrollState.autoScrollPlaying { scrollState.stopAutoScroll(); scrollState.startAutoScroll() }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // CENTER: Cook button always; auto-scroll controls appear next to it when cook mode is active
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    cookModeButton

                    if cookMode {
                        Divider().frame(height: 24).opacity(0.4)

                        // Play / Pause
                        Button {
                            scrollState.autoScrollPlaying.toggle()
                        } label: {
                            Image(systemName: scrollState.autoScrollPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(scrollState.autoScrollPlaying ? Color("Terracotta") : Color("AccentGreen"))
                        }

                        // Speed slider (tortoise → hare) — Pro feature
                        HStack(spacing: 6) {
                            Image(systemName: "tortoise")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                            ZStack(alignment: .trailing) {
                                ZStack {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.18))
                                        .frame(height: 4)
                                    Slider(value: Binding(
                                        get: { Double(scrollState.autoScrollSpeed) },
                                        set: { scrollState.autoScrollSpeed = Int($0.rounded()) }
                                    ), in: 0...4, step: 1)
                                    .tint(Color("AccentGreen"))
                                    .disabled(!proManager.isPro)
                                    .opacity(proManager.isPro ? 1.0 : 0.4)
                                }
                                .frame(minWidth: 200)
                                if !proManager.isPro {
                                    ProBadgeView(compact: true)
                                        .offset(x: -4)
                                }
                            }
                            Image(systemName: "hare")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 0.5)
                                )
                        )
                    }
                }
            }

            // RIGHT: Convert button (macOS) + Actions menu
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
                    UnitConverterView(servingMultiplier: servingMultiplier)
                }

                #endif

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
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shareRecipeCard(recipe: recipe)
                } label: {
                    if isRenderingCard {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isRenderingCard)
            }
            #endif
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
        .alert("Safety Check 🔥", isPresented: $showSafetyAlert) {
            Button("All clear, I checked!", role: .cancel) { }
        } message: {
            Text("Before you finish — please make sure all stoves, ovens, and burners are turned off. Safety first!")
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(message: toastMessage) {
                    withAnimation { showToast = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100)
            }
        }
        .animation(.easeInOut, value: showToast)
        .contentShape(Rectangle())
        .onTapGesture {
            if showToast {
                withAnimation { showToast = false }
            }
        }
        .onDisappear {
            scrollState.stopAutoScroll()
            timerManager.removeAll()
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
        guard let recipe = recipe else { return }
        let text = ExportImportService.recipeAsText(recipe, servingMultiplier: servingMultiplier)

        #if canImport(UIKit)
        var itemsToShare: [Any] = []

        switch format {
        case .text:
            itemsToShare = [text]
        case .pdf:
            if let pdfData = ExportImportService.exportRecipesAsPDF([recipe]) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe.title).pdf")
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
            if let pdfData = ExportImportService.exportRecipesAsPDF([recipe]) {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.pdf]
                savePanel.nameFieldStringValue = "\(recipe.title).pdf"
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

    #if os(macOS)
    @MainActor
    private func shareRecipeCard(recipe: Recipe) {
        guard !isRenderingCard else { return }
        isRenderingCard = true
        if let data = RecipeCardRenderer.render(recipe: recipe),
           let image = NSImage(data: data) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([image])
            toastMessage = "Recipe card copied! Paste into Instagram, Facebook or Messages."
            showToast = true
        }
        isRenderingCard = false
    }
    #endif

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
            if cookMode {
                // Collapsible header in cook mode
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        ingredientsExpanded.toggle()
                    }
                    HapticManager.light()
                } label: {
                    HStack {
                        Text("Ingredients")
                            .font(.system(size: 18 * cookModeFontSize, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(ingredientsExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.25), value: ingredientsExpanded)
                    }
                    .padding(.leading).padding(.trailing, 120)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text("Ingredients")
                        .font(.appHeadline)
                    Spacer()
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
                .padding(.horizontal)
            }

            if !cookMode || ingredientsExpanded {
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
                            .font(cookMode ? .system(size: 20 * cookModeFontSize) : .appBody)

                        Text(ingredientDisplayText(ingredient))
                            .font(cookMode ? .system(size: 20 * cookModeFontSize) : .appBody)
                            .strikethrough(ingredient.isChecked)
                            .opacity(ingredient.isChecked ? 0.5 : 1)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            } // end if !cookMode || ingredientsExpanded

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

        // Choose font based on cook mode
        let quantityFont: Font = cookMode
            ? .system(size: 20 * cookModeFontSize, weight: .bold)
            : .appBody.bold()

        // Bold the amount and unit, colored AccentGreen
        var result = AttributedString()
        if let amount = ingredient.amount {
            var amountStr = AttributedString(IngredientParser.scale(amount: amount, by: 1.0))
            amountStr.font = quantityFont
            amountStr.foregroundColor = Color("AccentGreen")
            result.append(amountStr)
            result.append(AttributedString(" "))
        }
        if let unit = ingredient.unit {
            var unitStr = AttributedString(unit)
            unitStr.font = quantityFont
            unitStr.foregroundColor = Color("AccentGreen")
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
                // In cook mode the row is split: the step-circle tap area marks the step
                // done, while the text content (with tappable timer chips) is non-tappable
                // at the outer level so inner Button taps are forwarded correctly.
                if cookMode {
                    HStack(alignment: .top, spacing: 12) {
                        // Step circle — tappable to mark complete
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
                        }
                        .buttonStyle(.plain)

                        // Instruction text — plain, no chips
                        Text(instruction.text)
                            .font(.system(size: 16 * cookModeFontSize))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(instruction.isCompleted ? 0.5 : 1)
                            .padding(.trailing, 120)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        activeStep == instruction.stepNumber
                            ? Color("AccentGreen").opacity(0.08)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                } else {
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
                                .font(.appBody)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Cook Mode Scroll Indicator (Bug 3 fix)
// An interactive scroll bar on the right edge in cook mode.
// The user can drag the capsule thumb to scroll the recipe content directly.
// Works with both touch drag (iOS/iPadOS) and mouse drag (macOS).

struct CookModeScrollIndicator: View {
    @Binding var scrollOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    /// True while the user is actively dragging the thumb.
    @State private var isDragging = false
    /// The scrollOffset value captured at the very start of the drag gesture.
    @State private var dragStartOffset: CGFloat = 0

    // Maximum scrollable distance in the content.
    private var maxScroll: CGFloat { max(0, contentHeight - viewportHeight) }

    // Proportional thumb height — at least 40 pt.
    private var thumbHeight: CGFloat {
        guard contentHeight > 0 else { return 40 }
        return max(40, viewportHeight * viewportHeight / contentHeight)
    }

    // The usable track length for the thumb to travel.
    private var trackHeight: CGFloat { max(0, viewportHeight - thumbHeight) }

    // Current thumb top position within the track.
    private var thumbY: CGFloat {
        guard maxScroll > 0 else { return 0 }
        return (scrollOffset / maxScroll * trackHeight).clamped(to: 0...trackHeight)
    }

    var body: some View {
        // Only show indicator when content is taller than the viewport.
        if maxScroll <= 0 {
            EmptyView()
        } else {
            GeometryReader { _ in
                // Subtle track background
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 6, height: viewportHeight - 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 7)
                    .padding(.top, 8)
                // Thumb capsule positioned via offset so the hit-test frame stays
                // exactly the thumb size and does not swallow the whole track.
                Capsule()
                    .fill(Color.primary.opacity(isDragging ? 0.6 : 0.4))
                    .frame(width: isDragging ? 14 : 12, height: thumbHeight)
                    .offset(y: thumbY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    // Animate width/opacity on drag state change.
                    .animation(.easeInOut(duration: 0.12), value: isDragging)
                    // minimumDistance: 0 so the gesture fires immediately on touch/click
                    // without requiring any movement threshold.
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    // Capture the baseline scrollOffset once at gesture start.
                                    isDragging = true
                                    dragStartOffset = scrollOffset
                                }
                                // Map thumb translation → content offset.
                                // deltaThumb / trackHeight == deltaContent / maxScroll
                                let scale: CGFloat = trackHeight > 0 ? maxScroll / trackHeight : 1
                                let next = (dragStartOffset + value.translation.height * scale)
                                    .clamped(to: 0...maxScroll)
                                scrollOffset = next
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .allowsHitTesting(true)
            }
            // Fixed width so the GeometryReader doesn't expand over recipe content.
            .frame(width: 20)
            .allowsHitTesting(true)
        }
    }
}

// MARK: - Comparable clamping helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Unit Converter (macOS Pro feature)

#if os(macOS)
struct UnitConverterView: View {
    var servingMultiplier: Double = 1.0

    enum CUnit: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case g = "g", oz = "oz", lb = "lb", kg = "kg"
        case tsp = "tsp", tbsp = "tbsp", floz = "fl oz", cup = "cup"
        case ml = "ml", l = "l", pt = "pt", qt = "qt", gal = "gal"

        var isWeight: Bool { [.g, .oz, .lb, .kg].contains(self) }

        // Weight: grams per unit. Volume: ml per unit.
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
    @State private var toUnit: CUnit = .g
    @State private var showProUpgrade = false
    @State private var ingredientQuery = ""
    @State private var selectedIngredient: IngredientWeightEntry? = nil
    @State private var suggestions: [IngredientWeightEntry] = []

    private var canConvert: Bool {
        if fromUnit.isWeight == toUnit.isWeight { return true }
        return selectedIngredient != nil
    }

    private var result: String {
        guard let value = Double(inputText), value >= 0 else { return "—" }
        let converted: Double
        if fromUnit.isWeight == toUnit.isWeight {
            converted = value * fromUnit.toBase / toUnit.toBase
        } else if let ing = selectedIngredient {
            let gpml = ing.gramsPerMl
            if !fromUnit.isWeight && toUnit.isWeight {
                // volume → weight
                converted = (value * fromUnit.toBase * gpml) / toUnit.toBase
            } else {
                // weight → volume
                converted = (value * fromUnit.toBase / gpml) / toUnit.toBase
            }
        } else {
            return "—"
        }
        if converted == 0 { return "0" }
        if converted >= 100 { return String(format: "%.1f", converted) }
        if converted >= 1   { return String(format: "%.2f", converted) }
        return String(format: "%.4f", converted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

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

                // Ingredient search for weight↔volume
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.appSubheadline)
                        TextField("Search ingredient (e.g. flour, butter…)", text: $ingredientQuery)
                            .onChange(of: ingredientQuery) { _, newVal in
                                selectedIngredient = nil
                                suggestions = newVal.count >= 2
                                    ? IngredientWeightDatabase.suggestions(for: newVal)
                                    : []
                            }
                        if !ingredientQuery.isEmpty {
                            Button {
                                ingredientQuery = ""
                                selectedIngredient = nil
                                suggestions = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Suggestions dropdown
                    if !suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(suggestions.prefix(6)), id: \.name) { entry in
                                Button {
                                    selectedIngredient = entry
                                    ingredientQuery = entry.name
                                    suggestions = []
                                } label: {
                                    HStack {
                                        Text(entry.name)
                                            .font(.appSubheadline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(String(format: "%.0fg / cup", entry.gramsPerMl * 236.588))
                                            .font(.appCaption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)
                                .background(Color.clear)
                                .onHover { inside in _ = inside }
                                if entry.name != suggestions.prefix(6).last?.name {
                                    Divider()
                                }
                            }
                        }
                        .background(.thickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    }

                    // Selected ingredient badge
                    if let ing = selectedIngredient {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color("AccentGreen"))
                                .font(.appCaption)
                            Text(ing.name)
                                .font(.appCaption.weight(.medium))
                                .foregroundStyle(Color("AccentGreen"))
                            Spacer()
                            Text("Weight ↔ Volume enabled")
                                .font(.appCaption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("AccentGreen").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Converter row
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
                        Text(fromUnit.isWeight != toUnit.isWeight
                             ? "Search an ingredient above to convert weight ↔ volume"
                             : "Enter a valid amount")
                            .font(.appCaption)
                            .foregroundStyle(Color("Terracotta"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Serving scale note
                if servingMultiplier != 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.appCaption2)
                        Text("Recipe is scaled ×\(String(format: "%.2g", servingMultiplier)) — adjust your amounts accordingly")
                            .font(.appCaption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
#endif

// MARK: - My Recipe Intro Sheet

struct MyRecipeIntroSheet: View {
    let originalTitle: String
    let onProceed: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("Terracotta"))

                VStack(spacing: 12) {
                    Text("Create My Recipe")
                        .font(.title2.bold())
                    Text("You're making **your own version** of \"\(originalTitle)\".")
                        .font(.appBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("The original stays untouched. Your copy will be saved as \"My \(originalTitle)\" so you can freely change ingredients, servings, and instructions.")
                        .font(.appSubheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    onProceed()
                } label: {
                    Text("Start Editing")
                        .font(.appHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("Terracotta"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            }
            .padding(.top, 24)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Recipe Sheet

struct EditRecipeSheet: View {
    enum Mode { case edit, copy }

    struct DraftIngredient: Identifiable {
        var id = UUID()
        var amount: String
        var unit: String
        var name: String
    }

    struct DraftInstruction: Identifiable {
        var id = UUID()
        var text: String
    }

    struct Draft {
        var imageData: Data?
        var title: String
        var servings: Int?
        var prepTime: String
        var cookTime: String
        var totalTime: String
        var notes: String
        var ingredients: [DraftIngredient]
        var instructions: [String]
    }

    let recipe: Recipe
    let mode: Mode
    let onSave: (Draft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var servings: Int
    @State private var prepTime: String
    @State private var cookTime: String
    @State private var totalTime: String
    @State private var notes: String
    @State private var ingredients: [DraftIngredient]
    @State private var instructions: [DraftInstruction]
    @State private var imageData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    #if os(macOS)
    @State private var showFilePicker = false
    #endif

    // macOS sidebar selection
    #if os(macOS)
    @State private var selectedSection: EditorSection? = .titleInfo
    #endif

    enum EditorSection: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case titleInfo    = "Title & Info"
        case ingredients  = "Ingredients"
        case instructions = "Instructions"
        case notes        = "Notes"

        var icon: String {
            switch self {
            case .titleInfo:    return "info.circle"
            case .ingredients:  return "list.bullet"
            case .instructions: return "number"
            case .notes:        return "note.text"
            }
        }
    }

    /// Parse an amount string that may contain Unicode fractions or mixed numbers like "1½".
    static func parseAmount(_ text: String) -> Double? {
        let fractionMap: [Character: Double] = [
            "½": 0.5, "⅓": 1.0/3, "⅔": 2.0/3, "¼": 0.25, "¾": 0.75,
            "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
        ]
        let s = text.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return nil }
        if let d = Double(s) { return d }
        if let last = s.unicodeScalars.last.map({ Character($0) }),
           let frac = fractionMap[last] {
            let prefix = String(s.dropLast())
            let whole = Double(prefix.trimmingCharacters(in: .whitespaces)) ?? 0
            return whole + frac
        }
        return nil
    }

    init(recipe: Recipe, mode: Mode, onSave: @escaping (Draft) -> Void) {
        self.recipe = recipe
        self.mode = mode
        self.onSave = onSave

        let defaultTitle = mode == .copy
            ? (recipe.title.hasPrefix("My ") ? recipe.title : "My \(recipe.title)")
            : recipe.title
        _title = State(initialValue: defaultTitle)
        _servings = State(initialValue: recipe.servings ?? 4)
        _prepTime = State(initialValue: recipe.prepTime ?? "")
        _cookTime = State(initialValue: recipe.cookTime ?? "")
        _totalTime = State(initialValue: recipe.totalTime ?? "")
        _notes = State(initialValue: recipe.notes ?? "")
        _ingredients = State(initialValue:
            recipe.ingredients
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { ing in
                    DraftIngredient(
                        amount: ing.amount.map { IngredientParser.scale(amount: $0, by: 1.0) } ?? "",
                        unit: ing.unit ?? "",
                        name: ing.name ?? ing.original
                    )
                }
        )
        _instructions = State(initialValue:
            recipe.instructions
                .sorted { $0.stepNumber < $1.stepNumber }
                .map { DraftInstruction(text: $0.text) }
        )
        _imageData = State(initialValue: recipe.imageData)
    }

    // MARK: - Save helper

    private func performSave() {
        let draft = Draft(
            imageData: imageData,
            title: title.trimmingCharacters(in: .whitespaces).isEmpty
                ? recipe.title : title.trimmingCharacters(in: .whitespaces),
            servings: servings,
            prepTime: prepTime.trimmingCharacters(in: .whitespaces),
            cookTime: cookTime.trimmingCharacters(in: .whitespaces),
            totalTime: totalTime.trimmingCharacters(in: .whitespaces),
            notes: notes,
            ingredients: ingredients,
            instructions: instructions.map { $0.text }
        )
        onSave(draft)
        dismiss()
    }

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    // MARK: - macOS: NavigationSplitView

    #if os(macOS)
    private var macBody: some View {
        NavigationSplitView {
            List(EditorSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selectedSection ?? .titleInfo {
                case .titleInfo:    macTitleInfoSection
                case .ingredients:  macIngredientsSection
                case .instructions: macInstructionsSection
                case .notes:        macNotesSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(mode == .copy ? "My Recipe" : "Edit Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(mode == .copy ? "Save Copy" : "Save") {
                    performSave()
                }
                .foregroundStyle(Color("AccentGreen"))
                .fontWeight(.semibold)
            }
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    // MARK: macOS detail sections

    private var macTitleInfoSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                editorSectionHeader("Title & Info")

                // Photo
                GroupBox("Photo") {
                    VStack(spacing: 10) {
                        if let imageData {
                            #if canImport(UIKit)
                            if let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable().scaledToFill()
                                    .frame(height: 160).frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            #else
                            if let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable().scaledToFill()
                                    .frame(height: 160).frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            #endif
                        }
                        HStack {
                            #if os(macOS)
                            Button {
                                let panel = NSOpenPanel()
                                panel.allowedContentTypes = [.image]
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK, let url = panel.url,
                                   let data = try? Data(contentsOf: url) {
                                    imageData = data
                                }
                            } label: {
                                Label(imageData == nil ? "Browse Files…" : "Change Photo", systemImage: "folder")
                            }
                            Divider().frame(height: 16)
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Photos Library", systemImage: "photo")
                            }
                            .onChange(of: selectedPhoto) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        imageData = data
                                    }
                                }
                            }
                            #else
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
                            #endif
                            if imageData != nil {
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    imageData = nil
                                    selectedPhoto = nil
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipe Title")
                        .font(.appSubheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Recipe title", text: $title)
                        .font(.title2.bold())
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Servings")
                        .font(.appSubheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Stepper(
                        "\(servings) serving\(servings == 1 ? "" : "s")",
                        value: $servings, in: 1...100
                    )
                    .font(.appBody)
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Times")
                        .font(.appSubheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prep Time").font(.appCaption).foregroundStyle(.secondary)
                            TextField("e.g. 15 min", text: $prepTime)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cook Time").font(.appCaption).foregroundStyle(.secondary)
                            TextField("e.g. 30 min", text: $cookTime)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Total Time").font(.appCaption).foregroundStyle(.secondary)
                            TextField("e.g. 45 min", text: $totalTime)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                        }
                    }
                }
            }
            .padding(28)
        }
    }

    private var macIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorSectionHeader("Ingredients")
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 16)

            List {
                ForEach($ingredients) { $ing in
                    HStack(spacing: 10) {
                        TextField("Amount", text: $ing.amount)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)

                        TextField("Unit", text: $ing.unit)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)

                        TextField("Ingredient name", text: $ing.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        Button {
                            withAnimation {
                                ingredients.removeAll { $0.id == ing.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    ingredients.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)

            Divider()

            Button {
                withAnimation {
                    ingredients.append(DraftIngredient(amount: "", unit: "", name: ""))
                }
            } label: {
                Label("Add Ingredient", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color("AccentGreen"))
                    .font(.appSubheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
    }

    private var macInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorSectionHeader("Instructions")
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 16)

            List {
                ForEach(Array($instructions.enumerated()), id: \.element.id) { index, $instr in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.appCaption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color("AccentGreen").opacity(0.7))
                            .clipShape(Circle())
                            .padding(.top, 6)

                        TextField("Step \(index + 1)…", text: $instr.text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...8)
                            .frame(maxWidth: .infinity)

                        Button {
                            withAnimation {
                                instructions.removeAll { $0.id == instr.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    instructions.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)

            Divider()

            Button {
                withAnimation {
                    instructions.append(DraftInstruction(text: ""))
                }
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color("AccentGreen"))
                    .font(.appSubheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
    }

    private var macNotesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                editorSectionHeader("Notes")

                TextEditor(text: $notes)
                    .font(.appBody)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func editorSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
    }
    #endif

    // MARK: - iOS: NavigationStack with tab-like section picker

    #if os(iOS)
    @State private var selectedSectioniOS: EditorSection = .titleInfo

    private var iosBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EditorSection.allCases) { section in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSectioniOS = section
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: section.icon)
                                        .font(.appCaption2)
                                    Text(section.rawValue)
                                        .font(.appCaption.weight(.medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    selectedSectioniOS == section
                                        ? Color("AccentGreen")
                                        : Color("AccentGreen").opacity(0.1)
                                )
                                .foregroundStyle(
                                    selectedSectioniOS == section ? .white : Color("AccentGreen")
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)

                Divider()

                // Content
                ScrollView {
                    switch selectedSectioniOS {
                    case .titleInfo:    iosTitleInfoSection
                    case .ingredients:  iosIngredientsSection
                    case .instructions: iosInstructionsSection
                    case .notes:        iosNotesSection
                    }
                }
            }
            .navigationTitle(mode == .copy ? "My Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .copy ? "Save Copy" : "Save") {
                        performSave()
                    }
                    .foregroundStyle(Color("AccentGreen"))
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: iOS detail sections

    private var iosTitleInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Photo
            VStack(alignment: .leading, spacing: 8) {
                Text("Photo")
                    .font(.appSubheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                VStack(spacing: 10) {
                    if let imageData {
                        #if canImport(UIKit)
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        #else
                        if let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        #endif
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                            .font(.appSubheadline.weight(.medium))
                            .foregroundStyle(Color("AccentGreen"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color("AccentGreen").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                imageData = data
                            }
                        }
                    }
                    if imageData != nil {
                        Button("Remove Photo", role: .destructive) {
                            imageData = nil
                            selectedPhoto = nil
                        }
                        .font(.appSubheadline)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recipe Title")
                    .font(.appSubheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Recipe title", text: $title)
                    .font(.title3.bold())
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Servings")
                    .font(.appSubheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Stepper(
                    "\(servings) serving\(servings == 1 ? "" : "s")",
                    value: $servings, in: 1...100
                )
                .font(.appBody)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Times")
                    .font(.appSubheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    timeRow(label: "Prep Time", placeholder: "e.g. 15 min", value: $prepTime)
                    Divider().padding(.leading, 16)
                    timeRow(label: "Cook Time", placeholder: "e.g. 30 min", value: $cookTime)
                    Divider().padding(.leading, 16)
                    timeRow(label: "Total Time", placeholder: "e.g. 45 min", value: $totalTime)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func timeRow(label: String, placeholder: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.appBody)
            Spacer()
            TextField(placeholder, text: value)
                .font(.appBody)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var iosIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($ingredients) { $ing in
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        TextField("Amount", text: $ing.amount)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 90)

                        TextField("Unit", text: $ing.unit)
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 90)

                        Button {
                            withAnimation {
                                ingredients.removeAll { $0.id == ing.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Ingredient name", text: $ing.name)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
            }

            Button {
                withAnimation {
                    ingredients.append(DraftIngredient(amount: "", unit: "", name: ""))
                }
            } label: {
                Label("Add Ingredient", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color("AccentGreen"))
                    .font(.appSubheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("AccentGreen").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            Text("Swipe a row left to delete, or tap the trash icon.")
                .font(.appCaption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    private var iosInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array($instructions.enumerated()), id: \.element.id) { index, $instr in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.appCaption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color("AccentGreen").opacity(0.7))
                        .clipShape(Circle())
                        .padding(.top, 10)

                    TextField("Step \(index + 1)…", text: $instr.text, axis: .vertical)
                        .lineLimit(2...8)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: .infinity)

                    Button {
                        withAnimation {
                            instructions.removeAll { $0.id == instr.id }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 16)
            }

            Button {
                withAnimation {
                    instructions.append(DraftInstruction(text: ""))
                }
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color("AccentGreen"))
                    .font(.appSubheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("AccentGreen").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    private var iosNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.appSubheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            TextEditor(text: $notes)
                .font(.appBody)
                .frame(minHeight: 200)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    #endif
}

// MARK: - FlameIcon
// Isolated subview so the flicker animation does not cause RecipeDetailView
// to re-render on every timer tick, which was jittering the toolbar buttons.
private struct FlameIcon: View {
    let cookMode: Bool
    @State private var flameColor: Color = .orange
    @State private var flameTimer: Timer?

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: cookMode ? "flame.fill" : "flame")
                .font(.system(size: 15, weight: .medium))
            Text(cookMode ? "Cooking" : "Cook")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
        }
        .foregroundStyle(cookMode ? flameColor : .primary)
        .frame(width: 72, height: 40)
        .background(
            Capsule()
                .fill(cookMode ? Color.orange.opacity(0.2) : Color.clear)
                .overlay(
                    Capsule()
                        .strokeBorder(cookMode ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .clipShape(Capsule())
        .onChange(of: cookMode) { _, active in
            if active { startFlicker() } else { stopFlicker() }
        }
        .onAppear { if cookMode { startFlicker() } }
        .onDisappear { stopFlicker() }
    }

    private func startFlicker() {
        stopFlicker()
        flameTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            let useDeep = Double.random(in: 0...1) > 0.4
            withAnimation(.easeInOut(duration: 0.12)) {
                flameColor = useDeep
                    ? Color(red: 1.0, green: 0.45, blue: 0.0)
                    : Color(red: 1.0, green: 0.75, blue: 0.1)
            }
        }
        RunLoop.main.add(flameTimer!, forMode: .common)
    }

    private func stopFlicker() {
        flameTimer?.invalidate()
        flameTimer = nil
        flameColor = .orange
    }
}

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
