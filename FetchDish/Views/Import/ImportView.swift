import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @State private var viewModel = RecipeImportViewModel()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showManualEntry = false
    @State private var showFileImporter = false

    private static let heroImages = ["ImportHero1", "ImportHero2", "ImportHero3"]
    private let currentHeroImage = heroImages.randomElement()!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero image (rotates each app launch)
                Image(currentHeroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 12)

                // Header text
                VStack(spacing: 8) {
                    Text("Import a Recipe")
                        .font(.title2.bold())

                    Text("Paste any recipe URL. We'll grab just the recipe — no ads, no life stories.")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // URL Input
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        TextField("https://example.com/recipe...", text: $viewModel.urlText)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit {
                                Task { await viewModel.importRecipe() }
                            }
                            .onChange(of: viewModel.urlText) {
                                if viewModel.showPinterestTip {
                                    viewModel.showPinterestTip = false
                                }
                            }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Paste from clipboard button
                    #if canImport(UIKit)
                    Button {
                        if let clip = UIPasteboard.general.string {
                            viewModel.urlText = clip
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            .font(.appSubheadline)
                    }
                    .tint(Color("AccentGreen"))
                    #endif
                }
                .padding(.horizontal)

                // Import button
                Button {
                    Task { await viewModel.importRecipe() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }
                        Text(viewModel.isLoading ? viewModel.loadingMessage : "Save Recipe")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(viewModel.isLoading || viewModel.urlText.isEmpty)
                .padding(.horizontal)

                // Pinterest tip image
                if viewModel.showPinterestTip {
                    Image("PinterestTip")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                // Error message
                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // File import option
                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.arrow.up")
                        Text("Import from File")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .tint(.primary)
                .padding(.horizontal)

                // Manual entry option
                Button {
                    showManualEntry = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Add Recipe Manually")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .tint(.primary)
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
        }
        .navigationTitle("Import")
        .sheet(isPresented: $viewModel.showPreview) {
            if let parsed = viewModel.parsedRecipe {
                RecipePreviewSheet(
                    parsed: parsed,
                    onSave: { editedTitle in
                        if !ProStatus.canSaveMore(currentCount: recipes.count) {
                            toastMessage = "Free limit reached! Upgrade to save more."
                            showToast = true
                            return
                        }
                        Task {
                            if let _ = await viewModel.saveRecipe(context: modelContext, title: editedTitle) {
                                toastMessage = "Recipe saved!"
                                showToast = true
                                HapticManager.success()
                            }
                        }
                    },
                    onCancel: {
                        viewModel.showPreview = false
                    }
                )
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualRecipeEntryView()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .plainText, .rtf, .pdf]
        ) { result in
            switch result {
            case .success(let url):
                Task { @MainActor in
                    importRecipes(from: url)
                }
            case .failure(let error):
                toastMessage = "Import failed: \(error.localizedDescription)"
                showToast = true
            }
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
    }
    
    // MARK: - Import Helper
    
    @MainActor
    private func importRecipes(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            toastMessage = "Cannot access file."
            showToast = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let currentCount = (try? modelContext.fetch(FetchDescriptor<Recipe>()))?.count ?? 0
            if !ProStatus.isPro && currentCount >= 25 {
                toastMessage = "Free limit reached! Upgrade to import more."
                showToast = true
                return
            }

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
}
