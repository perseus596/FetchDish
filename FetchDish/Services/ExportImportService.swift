import Foundation
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// Handles export/import of recipes for backup and sharing.
enum ExportImportService {

    // MARK: - JSON Export (preserves all data including images)
    
    static func exportRecipesAsJSON(_ recipes: [Recipe]) -> Data? {
        let bundle = ExportBundle(recipes: recipes.map { RecipeExport(from: $0) })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(bundle)
    }
    
    static func importRecipesFromJSON(from data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundle.self, from: data)
        
        var importedCount = 0
        for export in bundle.recipes {
            let recipe = Recipe(
                title: export.title,
                descriptionText: export.description,
                sourceUrl: export.sourceUrl,
                imageData: export.imageBase64.flatMap { Data(base64Encoded: $0) },
                prepTime: export.prepTime,
                cookTime: export.cookTime,
                totalTime: export.totalTime,
                servings: export.servings,
                ingredients: export.ingredients.enumerated().map { index, ing in
                    RecipeIngredient(
                        original: ing.original,
                        amount: ing.amount,
                        unit: ing.unit,
                        name: ing.name,
                        sortOrder: index
                    )
                },
                instructions: export.instructions.map { inst in
                    RecipeInstruction(
                        stepNumber: inst.stepNumber,
                        text: inst.text
                    )
                },
                notes: export.notes,
                tags: export.tags,
                calories: export.calories,
                fat: export.fat,
                carbs: export.carbs,
                protein: export.protein,
                fiber: export.fiber,
                sugar: export.sugar,
                cuisine: export.cuisine,
                mood: export.mood,
                dateAdded: export.dateAdded,
                dateModified: export.dateModified,
                isFavorite: export.isFavorite
            )
            
            context.insert(recipe)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }

    // MARK: - Text Export (for sharing, no images)

    /// Export recipes as plain text (for .txt files)
    static func exportRecipesAsText(_ recipes: [Recipe]) -> String {
        var lines: [String] = []
        
        lines.append("═══════════════════════════════════════════")
        lines.append("      FetchDish Recipe Collection")
        lines.append("      Exported: \(formattedDate())")
        lines.append("      \(recipes.count) Recipe\(recipes.count == 1 ? "" : "s")")
        lines.append("═══════════════════════════════════════════")
        lines.append("")
        lines.append("")
        
        for (index, recipe) in recipes.enumerated() {
            if index > 0 {
                lines.append("")
                lines.append("═══════════════════════════════════════════")
                lines.append("")
            }
            
            lines.append(recipeAsText(recipe, servingMultiplier: 1.0))
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Export recipes as formatted text (suitable for conversion to PDF/DOC/Pages)
    static func exportRecipesAsRichText(_ recipes: [Recipe]) -> Data? {
        #if canImport(UIKit) || canImport(AppKit)
        let textString = exportRecipesAsText(recipes)
        
        // Create attributed string with better formatting
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(ofSize: 12),
            .paragraphStyle: style
        ]
        
        let attributedString = NSAttributedString(string: textString, attributes: attributes)
        
        // Convert to RTF data
        #if canImport(UIKit)
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        #else
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        #endif
        #else
        return nil
        #endif
    }
    
    /// Export recipes as PDF
    static func exportRecipesAsPDF(_ recipes: [Recipe]) -> Data? {
        #if canImport(UIKit)
        let textString = exportRecipesAsText(recipes)
        
        // Create attributed string
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(ofSize: 11),
            .paragraphStyle: style
        ]
        
        let attributedString = NSAttributedString(string: textString, attributes: attributes)
        
        // Create PDF context
        let pdfMetadata = [
            kCGPDFContextCreator: "FetchDish",
            kCGPDFContextTitle: "Recipe Collection",
            kCGPDFContextAuthor: "FetchDish User"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            var currentY: CGFloat = 50
            let margin: CGFloat = 50
            let pageWidth = pageRect.width - (margin * 2)
            
            for (index, recipe) in recipes.enumerated() {
                if index > 0 {
                    // Start new page for each recipe
                    context.beginPage()
                    currentY = 50
                }
                
                // Draw recipe
                let recipeText = recipeAsText(recipe, servingMultiplier: 1.0)
                let recipeAttributes: [NSAttributedString.Key: Any] = [
                    .font: platformFont(ofSize: 11),
                    .paragraphStyle: style
                ]
                let recipeAttributedString = NSAttributedString(string: recipeText, attributes: recipeAttributes)
                
                let textRect = CGRect(x: margin, y: currentY, width: pageWidth, height: pageRect.height - currentY - margin)
                recipeAttributedString.draw(in: textRect)
            }
        }
        #else
        return nil
        #endif
    }

    /// Export a single recipe as shareable plain text.
    static func recipeAsText(_ recipe: Recipe, servingMultiplier: Double = 1.0) -> String {
        var lines: [String] = []
        lines.append(recipe.title)
        lines.append(String(repeating: "=", count: recipe.title.count))
        lines.append("")

        if let desc = recipe.descriptionText, !desc.isEmpty {
            lines.append(desc)
            lines.append("")
        }

        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let total = recipe.totalTime { meta.append("Total: \(total)") }
        if let servings = recipe.servings { 
            let adjustedServings = Int(Double(servings) * servingMultiplier)
            meta.append("Servings: \(adjustedServings)") 
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " | "))
            lines.append("")
        }

        if !recipe.ingredients.isEmpty {
            lines.append("INGREDIENTS")
            lines.append("-----------")
            for ingredient in recipe.ingredients.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let text = IngredientParser.scaledText(ingredient: ingredient, multiplier: servingMultiplier)
                lines.append("• \(text)")
            }
            lines.append("")
        }

        if !recipe.instructions.isEmpty {
            lines.append("INSTRUCTIONS")
            lines.append("------------")
            for instruction in recipe.instructions.sorted(by: { $0.stepNumber < $1.stepNumber }) {
                lines.append("\(instruction.stepNumber). \(instruction.text)")
                lines.append("")
            }
        }

        if let notes = recipe.notes, !notes.isEmpty {
            lines.append("NOTES")
            lines.append("-----")
            lines.append(notes)
            lines.append("")
        }

        // Nutrition info
        var nutrition: [String] = []
        if let cal = recipe.calories { nutrition.append("Calories: \(cal)") }
        if let protein = recipe.protein { nutrition.append("Protein: \(protein)") }
        if let carbs = recipe.carbs { nutrition.append("Carbs: \(carbs)") }
        if let fat = recipe.fat { nutrition.append("Fat: \(fat)") }
        if !nutrition.isEmpty {
            lines.append("NUTRITION")
            lines.append("---------")
            lines.append(nutrition.joined(separator: " | "))
            lines.append("")
        }

        // Tags
        if !recipe.tags.isEmpty {
            lines.append("Tags: \(recipe.tags.joined(separator: ", "))")
            lines.append("")
        }

        if let url = recipe.sourceUrl {
            lines.append("Source: \(url)")
            lines.append("")
        }

        lines.append("— Saved with FetchDish")

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    /// Import recipes from text-based formats
    static func importRecipes(from data: Data, fileExtension: String, into context: ModelContext) throws -> Int {
        var text: String?
        
        // Extract text based on file type
        switch fileExtension.lowercased() {
        case "txt":
            text = String(data: data, encoding: .utf8)
            
        case "rtf", "rtfd", "doc", "docx":
            // Try to read as RTF/Word document
            #if canImport(UIKit) || canImport(AppKit)
            if let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                text = attributedString.string
            } else if let plainText = String(data: data, encoding: .utf8) {
                text = plainText
            }
            #else
            text = String(data: data, encoding: .utf8)
            #endif
            
        case "pdf":
            // Extract text from PDF
            #if canImport(PDFKit)
            if let pdfDocument = PDFDocument(data: data) {
                var pdfText = ""
                for pageIndex in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: pageIndex),
                       let pageContent = page.string {
                        pdfText += pageContent + "\n"
                    }
                }
                text = pdfText
            }
            #else
            throw ImportError.unsupportedFormat
            #endif
            
        case "pages":
            // Pages files are actually packages, try to extract text
            text = String(data: data, encoding: .utf8)
            
        default:
            // Try as plain text
            text = String(data: data, encoding: .utf8)
        }
        
        guard let text = text, !text.isEmpty else {
            throw ImportError.emptyFile
        }
        
        // Parse the text into recipes
        let recipes = try parseRecipesFromText(text)
        
        // Insert into context
        var importedCount = 0
        for parsedRecipe in recipes {
            let recipe = Recipe(
                title: parsedRecipe.title,
                descriptionText: parsedRecipe.description,
                sourceUrl: parsedRecipe.sourceUrl,
                prepTime: parsedRecipe.prepTime,
                cookTime: parsedRecipe.cookTime,
                totalTime: parsedRecipe.totalTime,
                servings: parsedRecipe.servings,
                ingredients: parsedRecipe.ingredients.enumerated().map { index, text in
                    let parsed = IngredientParser.parse(text)
                    return RecipeIngredient(
                        original: text,
                        amount: parsed.amount,
                        unit: parsed.unit,
                        name: parsed.name,
                        sortOrder: index
                    )
                },
                instructions: parsedRecipe.instructions.enumerated().map { index, text in
                    RecipeInstruction(stepNumber: index + 1, text: text)
                },
                notes: parsedRecipe.notes,
                tags: parsedRecipe.tags,
                calories: parsedRecipe.nutrition["Calories"],
                fat: parsedRecipe.nutrition["Fat"],
                carbs: parsedRecipe.nutrition["Carbs"],
                protein: parsedRecipe.nutrition["Protein"]
            )
            
            context.insert(recipe)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    // MARK: - Text Parsing
    
    struct ParsedRecipeData {
        var title: String
        var description: String?
        var sourceUrl: String?
        var prepTime: String?
        var cookTime: String?
        var totalTime: String?
        var servings: Int?
        var ingredients: [String]
        var instructions: [String]
        var notes: String?
        var tags: [String]
        var nutrition: [String: String]
    }
    
    enum ImportError: LocalizedError {
        case unsupportedFormat
        case emptyFile
        case noRecipesFound
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "This file format is not supported."
            case .emptyFile:
                return "The file appears to be empty."
            case .noRecipesFound:
                return "No recipes could be found in this file."
            }
        }
    }
    
    /// Parse text content into recipe data structures
    private static func parseRecipesFromText(_ text: String) throws -> [ParsedRecipeData] {
        var recipes: [ParsedRecipeData] = []
        
        // Split by recipe separator
        let recipeSections = text.components(separatedBy: "═══════════════════════════════════════════")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.contains("FetchDish Recipe Collection") }
        
        // If no separators found, treat entire content as one recipe
        let sections = recipeSections.isEmpty ? [text] : recipeSections
        
        for section in sections {
            if let recipe = parseRecipeSection(section) {
                recipes.append(recipe)
            }
        }
        
        if recipes.isEmpty {
            throw ImportError.noRecipesFound
        }
        
        return recipes
    }
    
    private static func parseRecipeSection(_ text: String) -> ParsedRecipeData? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard !lines.isEmpty else { return nil }
        
        var title = ""
        var description: String?
        var sourceUrl: String?
        var prepTime: String?
        var cookTime: String?
        var totalTime: String?
        var servings: Int?
        var ingredients: [String] = []
        var instructions: [String] = []
        var notes: String?
        var tags: [String] = []
        var nutrition: [String: String] = [:]
        
        var currentSection: String = ""
        var i = 0
        
        // Parse title (first non-empty line that's not just separators)
        while i < lines.count {
            let line = lines[i]
            if !line.isEmpty && !line.allSatisfy({ $0 == "=" || $0 == "-" || $0 == "═" }) {
                title = line
                i += 1
                break
            }
            i += 1
        }
        
        // Parse rest of the content
        while i < lines.count {
            let line = lines[i]
            
            // Skip separator lines
            if line.allSatisfy({ $0 == "=" || $0 == "-" || $0 == "═" }) {
                i += 1
                continue
            }
            
            // Detect sections
            let upperLine = line.uppercased()
            if upperLine == "INGREDIENTS" {
                currentSection = "ingredients"
                i += 1
                continue
            } else if upperLine == "INSTRUCTIONS" {
                currentSection = "instructions"
                i += 1
                continue
            } else if upperLine == "NOTES" {
                currentSection = "notes"
                i += 1
                continue
            } else if upperLine == "NUTRITION" {
                currentSection = "nutrition"
                i += 1
                continue
            } else if line.hasPrefix("Source:") {
                sourceUrl = line.replacingOccurrences(of: "Source:", with: "").trimmingCharacters(in: .whitespaces)
                i += 1
                continue
            } else if line.hasPrefix("Tags:") {
                let tagString = line.replacingOccurrences(of: "Tags:", with: "").trimmingCharacters(in: .whitespaces)
                tags = tagString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                i += 1
                continue
            } else if line.contains("Prep:") || line.contains("Cook:") || line.contains("Total:") || line.contains("Servings:") {
                // Parse metadata line
                let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                for part in parts {
                    if part.hasPrefix("Prep:") {
                        prepTime = part.replacingOccurrences(of: "Prep:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if part.hasPrefix("Cook:") {
                        cookTime = part.replacingOccurrences(of: "Cook:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if part.hasPrefix("Total:") {
                        totalTime = part.replacingOccurrences(of: "Total:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if part.hasPrefix("Servings:") {
                        let servingStr = part.replacingOccurrences(of: "Servings:", with: "").trimmingCharacters(in: .whitespaces)
                        servings = Int(servingStr.components(separatedBy: .whitespaces).first ?? "")
                    }
                }
                i += 1
                continue
            } else if line.hasPrefix("—") || line.contains("Saved with FetchDish") {
                // Footer, skip
                i += 1
                continue
            }
            
            // Add content to current section
            if !line.isEmpty {
                switch currentSection {
                case "ingredients":
                    let cleaned = line.replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        ingredients.append(cleaned)
                    }
                    
                case "instructions":
                    let cleaned = line.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        instructions.append(cleaned)
                    }
                    
                case "notes":
                    if notes == nil {
                        notes = line
                    } else {
                        notes! += "\n" + line
                    }
                    
                case "nutrition":
                    // Parse nutrition info (e.g., "Calories: 250 | Protein: 20g")
                    let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    for part in parts {
                        if let colonIndex = part.firstIndex(of: ":") {
                            let key = String(part[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                            let value = String(part[part.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                            nutrition[key] = value
                        }
                    }
                    
                default:
                    // Likely description
                    if description == nil && !line.isEmpty && currentSection.isEmpty {
                        description = line
                    }
                }
            }
            
            i += 1
        }
        
        // Validate minimum requirements
        guard !title.isEmpty else { return nil }
        
        return ParsedRecipeData(
            title: title,
            description: description,
            sourceUrl: sourceUrl,
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: totalTime,
            servings: servings,
            ingredients: ingredients,
            instructions: instructions,
            notes: notes,
            tags: tags,
            nutrition: nutrition
        )
    }
    
    // MARK: - Helpers
    
    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private static func platformFont(ofSize size: CGFloat) -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: size)
        #else
        return NSFont.systemFont(ofSize: size)
        #endif
    }
}

// MARK: - Type Aliases

#if canImport(UIKit)
typealias PlatformFont = UIFont
#else
typealias PlatformFont = NSFont
#endif

// MARK: - JSON Export/Import Models
struct ExportBundle: Codable {
    let recipes: [RecipeExport]
    let exportDate: Date = Date()
    let appVersion: String = "1.0"
}

struct RecipeExport: Codable {
    let title: String
    let description: String?
    let sourceUrl: String?
    let imageBase64: String?
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?
    let servings: Int?
    let ingredients: [IngredientExport]
    let instructions: [InstructionExport]
    let notes: String?
    let tags: [String]
    let calories: String?
    let fat: String?
    let carbs: String?
    let protein: String?
    let fiber: String?
    let sugar: String?
    let cuisine: String?
    let mood: String?
    let dateAdded: Date
    let dateModified: Date
    let isFavorite: Bool
    
    init(from recipe: Recipe) {
        self.title = recipe.title
        self.description = recipe.descriptionText
        self.sourceUrl = recipe.sourceUrl
        self.imageBase64 = recipe.imageData?.base64EncodedString()
        self.prepTime = recipe.prepTime
        self.cookTime = recipe.cookTime
        self.totalTime = recipe.totalTime
        self.servings = recipe.servings
        self.ingredients = recipe.ingredients.map { IngredientExport(from: $0) }
        self.instructions = recipe.instructions.map { InstructionExport(from: $0) }
        self.notes = recipe.notes
        self.tags = recipe.tags
        self.calories = recipe.calories
        self.fat = recipe.fat
        self.carbs = recipe.carbs
        self.protein = recipe.protein
        self.fiber = recipe.fiber
        self.sugar = recipe.sugar
        self.cuisine = recipe.cuisine
        self.mood = recipe.mood
        self.dateAdded = recipe.dateAdded
        self.dateModified = recipe.dateModified
        self.isFavorite = recipe.isFavorite
    }
}

struct IngredientExport: Codable {
    let original: String
    let amount: Double?
    let unit: String?
    let name: String?
    
    init(from ingredient: RecipeIngredient) {
        self.original = ingredient.original
        self.amount = ingredient.amount
        self.unit = ingredient.unit
        self.name = ingredient.name
    }
}

struct InstructionExport: Codable {
    let stepNumber: Int
    let text: String
    
    init(from instruction: RecipeInstruction) {
        self.stepNumber = instruction.stepNumber
        self.text = instruction.text
    }
}

