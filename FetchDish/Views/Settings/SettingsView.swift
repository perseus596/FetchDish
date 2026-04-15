import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]

    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("cookModeFontSize") private var cookModeFontSize: Double = 1.4

    @State private var showExportMenu = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showClearConfirm = false
    @State private var showProUpgrade = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var exportData: Data?
    @State private var exportFormat: ExportFormat = .txt
    
    enum ExportFormat {
        case txt, rtf, pdf, json
        
        var contentType: UTType {
            switch self {
            case .txt: return .plainText
            case .rtf: return .rtf
            case .pdf: return .pdf
            case .json: return .json
            }
        }
        
        var fileExtension: String {
            switch self {
            case .txt: return "txt"
            case .rtf: return "rtf"
            case .pdf: return "pdf"
            case .json: return "json"
            }
        }
        
        var displayName: String {
            switch self {
            case .txt: return "Text (.txt)"
            case .rtf: return "Rich Text (.rtf/.doc)"
            case .pdf: return "PDF"
            case .json: return "JSON Backup (with images)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                // Cook Mode
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cook Mode Font Size")
                            Spacer()
                            Text(String(format: "%.1f", cookModeFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $cookModeFontSize, in: 1.0...2.0, step: 0.1)
                            .tint(Color("AccentGreen"))

                        Text("The quick brown fox jumps over the lazy dog.")
                            .font(.system(size: 16 * cookModeFontSize))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Cook Mode")
                } footer: {
                    Text("Adjust font size when Cook Mode is active.")
                }

                // Data
                Section("Data") {
                    Menu {
                        Button {
                            exportRecipes(format: .json)
                        } label: {
                            Label("JSON Backup (includes images)", systemImage: "doc.badge.gearshape")
                        }
                        
                        Divider()
                        
                        Button {
                            exportRecipes(format: .txt)
                        } label: {
                            Label("Text File (.txt)", systemImage: "doc.text")
                        }
                        
                        Button {
                            exportRecipes(format: .rtf)
                        } label: {
                            Label("Rich Text (.rtf/.doc)", systemImage: "doc.richtext")
                        }
                        
                        Button {
                            exportRecipes(format: .pdf)
                        } label: {
                            Label("PDF Document", systemImage: "doc.fill")
                        }
                    } label: {
                        Label("Export All Recipes", systemImage: "square.and.arrow.up")
                    }
                    .disabled(recipes.isEmpty)

                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import Recipes", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // Pro
                Section {
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
                } header: {
                    Text("Subscription")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Recipes Saved")
                        Spacer()
                        Text("\(recipes.count)")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://fetchdish.com")!) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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
                allowedContentTypes: [.json, .plainText, .rtf, .pdf, .data]
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
                    ToastView(message: toastMessage) {
                        withAnimation { showToast = false }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 100)
                }
            }
            .animation(.easeInOut, value: showToast)
        }
    }

    // MARK: - Actions

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
        case .json:
            data = ExportImportService.exportRecipesAsJSON(recipes)
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
            let fileExtension = url.pathExtension.lowercased()
            
            let count: Int
            if fileExtension == "json" {
                // Try JSON import first (preserves images)
                count = try ExportImportService.importRecipesFromJSON(from: data, into: modelContext)
            } else {
                // Fall back to text-based import
                count = try ExportImportService.importRecipes(from: data, fileExtension: fileExtension, into: modelContext)
            }
            
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

// MARK: - File Export Document

struct GenericExportDocument: FileDocument {
    let data: Data
    let contentType: UTType
    
    static var readableContentTypes: [UTType] { [.json, .plainText, .rtf, .pdf, .data] }

    init(data: Data, contentType: UTType = .plainText) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = .data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Pro Upgrade Sheet

struct ProUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "star.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color("AccentGreen"))

                Text("FetchDish Pro")
                    .font(.title.bold())

                Text("Unlock the full experience")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ProFeatureRow(icon: "infinity", text: "Unlimited recipes")
                    ProFeatureRow(icon: "square.and.arrow.up", text: "Full export capabilities")
                    ProFeatureRow(icon: "cart.fill", text: "Multiple shopping lists")
                    ProFeatureRow(icon: "heart.fill", text: "Support indie development")
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        ProStatus.unlockPro()
                        dismiss()
                    } label: {
                        Text("Unlock Pro — \(ProManager.shared.product.map { $0.displayPrice } ?? "$19.99")")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("One-time purchase. No subscription.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color("AccentGreen"))
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}
