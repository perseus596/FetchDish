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
            
            recipe.dietaryTags = export.dietaryTags
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
        // macOS implementation using Core Graphics + CTFramesetter for proper pagination
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 50
        let textRect = CGRect(x: margin, y: margin,
                              width: pageRect.width - margin * 2,
                              height: pageRect.height - margin * 2)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var mediaBox = pageRect
        let contextOptions: CFDictionary = [
            kCGPDFContextCreator: "FetchDish",
            kCGPDFContextTitle: "Recipe Collection"
        ] as CFDictionary
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, contextOptions) else {
            return nil
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ]

        // Build full text: each recipe separated by a page-break marker we handle manually
        for recipe in recipes {
            let recipeText = recipeAsText(recipe, servingMultiplier: 1.0)
            let attributed = NSAttributedString(string: recipeText, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

            var textPosition = 0
            let totalLength = attributed.length

            while textPosition < totalLength {
                context.beginPage(mediaBox: &mediaBox)

                // White background
                context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                context.fill(pageRect)

                let path = CGPath(rect: textRect, transform: nil)
                let range = CFRange(location: textPosition, length: 0)
                let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)

                CTFrameDraw(frame, context)

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                textPosition += visibleRange.length

                context.endPage()

                if visibleRange.length == 0 { break } // safety: avoid infinite loop
            }
        }

        context.closePDF()
        return pdfData as Data
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
        case "json":
            return try importRecipesFromJSON(from: data, into: context)

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
            #if canImport(PDFKit)
            if let pdfDocument = PDFDocument(data: data) {
                // Check if this is a multi-recipe PDF by counting Ingredients/Directions pairs
                var pages: [String] = []
                for pageIndex in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: pageIndex),
                       let pageContent = page.string {
                        pages.append(pageContent)
                    }
                }
                let fullText = pages.joined(separator: "\n")
                // Count how many "Ingredients" + "Directions" pairs exist
                let lowerText = fullText.lowercased()
                let ingredientCount = lowerText.components(separatedBy: "\ningredients").count - 1
                    + (lowerText.hasPrefix("ingredients") ? 1 : 0)
                if ingredientCount > 1 {
                    // Multi-recipe PDF — use smart splitter
                    let extracted = extractMultipleRecipesFromPDFPages(pages)
                    let recipes = try parseRecipesFromText(extracted)
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
                                    original: text, amount: parsed.amount,
                                    unit: parsed.unit, name: parsed.name, sortOrder: index
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
                } else {
                    text = fullText
                }
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
            } else if upperLine == "INSTRUCTIONS" || upperLine == "DIRECTIONS" || upperLine == "STEPS" || upperLine == "METHOD" {
                currentSection = "instructions"
                i += 1
                continue
            } else if upperLine == "NOTES" || upperLine == "NOTE" || upperLine == "TIPS" || upperLine == "VARIATIONS" {
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
                    let cleaned = line.replacingOccurrences(of: "^\\d+[.)\\s]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        let startsNewStep = line.range(of: "^\\d+[.)\\s]", options: .regularExpression) != nil

                        // Stop joining if this line looks like a new recipe title or section header:
                        // - Matches "NN RecipeName" pattern (page number + title, e.g. "30 Roasted Vegetables")
                        // - Looks like an ingredient (starts with a number/fraction followed by a unit word)
                        let isPageNumberTitle = cleaned.range(of: #"^\d{1,2}\s+[A-Z][a-zA-Z]"#, options: .regularExpression) != nil
                        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        let isShortTitle = words.count <= 5 &&
                            (cleaned.first?.isUppercase == true) &&
                            !cleaned.hasSuffix(".") &&
                            !cleaned.hasSuffix(",") &&
                            !cleaned.contains(" and ") &&
                            !cleaned.contains(" or ") &&
                            !cleaned.contains(" with ") &&
                            !cleaned.contains(" to ") &&
                            cleaned.range(of: #"^\d"#, options: .regularExpression) == nil
                        let isIngredientLine = cleaned.range(of: #"^[\d½¼¾⅓⅔⅛]"#, options: .regularExpression) != nil
                        let looksLikeNewRecipeContent = isPageNumberTitle || isIngredientLine

                        if startsNewStep || instructions.isEmpty {
                            instructions.append(cleaned)
                        } else if looksLikeNewRecipeContent {
                            // This line belongs to a new recipe — stop joining, don't append at all
                            // (it will be handled by a separate recipe block)
                            break
                        } else {
                            // Genuine continuation line — join to previous instruction
                            instructions[instructions.count - 1] += " " + cleaned
                        }
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

    /// Splits a multi-recipe PDF (pages array) into FetchDish-separator-delimited text
    /// by detecting Ingredients/Directions blocks as recipe boundaries.
    private static func extractMultipleRecipesFromPDFPages(_ pages: [String]) -> String {
        let separator = "═══════════════════════════════════════════"

        // Lines that indicate a nutrition facts page — skip these
        let nutritionMarkers = ["% Daily Value", "Saturated Fat", "Trans Fat",
                                "Cholesterol", "Dietary Fiber", "Total Sugars",
                                "Vitamin D", "Nutrition Facts", "Serving size",
                                "servings per container", "Daily Value"]

        // Lines to skip entirely (boilerplate)
        let boilerplateMarkers = ["This material was funded", "Table of Contents", "Freezing Tips",
                                   "Cooking Tools", "Storing Fresh", "Keep It Safe", "Kitchen Measuring",
                                   "SNAP-Ed", "foodhero.org"]

        func isNutritionPage(_ text: String) -> Bool {
            let lines = text.components(separatedBy: .newlines).prefix(3).map { $0.trimmingCharacters(in: .whitespaces) }
            return lines.first == "Calories" && lines.contains(where: { $0.lowercased().contains("serving size") || $0.lowercased().contains("servings per") })
        }

        func isBoilerplatePage(_ text: String) -> Bool {
            boilerplateMarkers.contains { text.contains($0) }
        }

        /// Removes nutrition label blocks from a page's text, keeping only recipe content.
        func stripNutritionBlocks(_ text: String) -> String {
            let lines = text.components(separatedBy: .newlines)
            var result: [String] = []
            var inNutritionBlock = false
            var nutritionLineCount = 0

            let nutritionKeywords = [
                "% daily value", "total fat", "saturated fat", "trans fat",
                "cholesterol", "sodium", "total carbohydrate", "dietary fiber",
                "total sugars", "added sugars", "vitamin d", "vitamin a", "vitamin c",
                "calcium", "iron", "potassium", "serving size", "servings per container",
                "amount per serving", "daily value", "nutrition facts",
                "calories from fat", "monounsaturated", "polyunsaturated"
            ]

            func isNutritionLine(_ line: String) -> Bool {
                let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
                // Pure number or percentage lines
                if lower.isEmpty { return false }
                // Lines that are just "Calories" alone or "Calories X"
                if lower.hasPrefix("calories") && lower.count < 20 { return true }
                // Lines matching nutrition keywords
                if nutritionKeywords.contains(where: { lower.contains($0) }) { return true }
                // Lines that look like "Xg X%" or "Xmg X%" patterns (nutrient amounts)
                let pattern = #"^\d+(\.\d+)?\s*(g|mg|mcg|kcal|%|IU)"#
                if lower.range(of: pattern, options: .regularExpression) != nil { return true }
                // Lines like "X% X%" or containing just percentages
                if lower.range(of: #"^\d+%"#, options: .regularExpression) != nil { return true }
                // "servings per container" style
                if lower.contains("per container") || lower.contains("per serving") { return true }
                // Lines like "8 servings per container Serving size"
                if lower.range(of: #"^\d+\s+servings"#, options: .regularExpression) != nil { return true }
                return false
            }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if isNutritionLine(trimmed) {
                    inNutritionBlock = true
                    nutritionLineCount += 1
                    continue
                }
                // If we were in a nutrition block and see "Ingredients" or recipe keywords, stop skipping
                let upper = trimmed.uppercased()
                if inNutritionBlock {
                    // End nutrition block when we hit recipe content
                    if upper == "INGREDIENTS" || upper == "DIRECTIONS" || upper == "INSTRUCTIONS" {
                        inNutritionBlock = false
                        nutritionLineCount = 0
                        result.append(trimmed)
                        continue
                    }
                    // Non-nutrition line after a small block — might be a title or transition
                    if nutritionLineCount < 3 {
                        inNutritionBlock = false
                        nutritionLineCount = 0
                        result.append(trimmed)
                    }
                    // Otherwise keep skipping (still in long nutrition block)
                    continue
                }
                result.append(trimmed)
            }
            return result.joined(separator: "\n")
        }

        // Flatten all pages into lines, skipping nutrition/boilerplate pages
        var allLines: [String] = []
        for page in pages {
            if isBoilerplatePage(page) { continue }
            // If nutrition page but has recipe content, strip the nutrition block and keep recipe
            let cleaned = stripNutritionBlocks(page)
            let pageLines = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            // Only skip if after stripping there's no recipe content left
            let hasRecipeContent = pageLines.contains { $0.uppercased() == "INGREDIENTS" || $0.uppercased() == "DIRECTIONS" || $0.uppercased() == "INSTRUCTIONS" }
            if isNutritionPage(page) && !hasRecipeContent { continue }
            allLines.append(contentsOf: pageLines)
            allLines.append("") // page break marker
        }

        // Split into recipe blocks: each block starts just before an "Ingredients" line
        var chunks: [[String]] = []
        var currentBlock: [String] = []
        var lastPotentialTitle: String? = nil

        for line in allLines {
            let upper = line.uppercased()
            if upper == "INGREDIENTS" {
                // Check if currentBlock already has its own Ingredients header
                let hasIngredients = currentBlock.contains { $0.uppercased() == "INGREDIENTS" }
                if hasIngredients {
                    // Save the current block as a complete recipe
                    chunks.append(currentBlock)
                    // Look back up to 5 lines for the title of the new recipe
                    let lookback = min(5, currentBlock.count)
                    let titleCandidates = currentBlock.suffix(lookback).filter {
                        $0.count > 3 &&
                        !$0.isEmpty &&
                        !$0.uppercased().hasPrefix("DIRECTIONS") &&
                        !$0.uppercased().hasPrefix("INSTRUCTIONS") &&
                        !$0.hasPrefix("Prep") &&
                        !$0.hasPrefix("Makes") &&
                        !$0.hasPrefix("Serves") &&
                        !$0.contains("Food Hero") &&
                        !$0.hasPrefix("•") &&
                        !($0.first?.isNumber ?? false)
                    }
                    let title = titleCandidates.last ?? lastPotentialTitle
                    currentBlock = []
                    if let t = title {
                        currentBlock.append("TITLE: \(t)")
                    }
                    lastPotentialTitle = nil
                } else if !currentBlock.isEmpty {
                    // currentBlock has lines but no Ingredients yet — look for title among them
                    let lookback = min(5, currentBlock.count)
                    let titleCandidates = currentBlock.suffix(lookback).filter {
                        $0.count > 3 &&
                        !$0.isEmpty &&
                        !$0.uppercased().hasPrefix("DIRECTIONS") &&
                        !$0.uppercased().hasPrefix("INSTRUCTIONS") &&
                        !$0.hasPrefix("Prep") &&
                        !$0.hasPrefix("Makes") &&
                        !$0.hasPrefix("Serves") &&
                        !$0.contains("Food Hero") &&
                        !$0.hasPrefix("•") &&
                        !($0.first?.isNumber ?? false)
                    }
                    let title = titleCandidates.last ?? lastPotentialTitle
                    currentBlock = []
                    if let t = title {
                        currentBlock.append("TITLE: \(t)")
                    }
                    lastPotentialTitle = nil
                }
                currentBlock.append(line)
            } else {
                // Track potential recipe titles (proper-cased lines that look like recipe names)
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if !trimmedLine.isEmpty &&
                   trimmedLine.count > 4 &&
                   !trimmedLine.hasPrefix("•") &&
                   !trimmedLine.hasPrefix("-") &&
                   !(trimmedLine.first?.isNumber ?? false) &&
                   !trimmedLine.uppercased().hasPrefix("PREP") &&
                   !trimmedLine.uppercased().hasPrefix("MAKES") &&
                   !trimmedLine.uppercased().hasPrefix("COOK") &&
                   !trimmedLine.uppercased().hasPrefix("DIRECTIONS") &&
                   !trimmedLine.uppercased().hasPrefix("INSTRUCTIONS") &&
                   !trimmedLine.lowercased().contains("serving") &&
                   trimmedLine.first?.isUppercase == true {
                    lastPotentialTitle = trimmedLine
                }
                // Detect "NN RecipeName" pattern — page number followed by title
                // e.g. "30 Roasted Vegetables", "27 Skillet Mac and Cheese"
                if line.range(of: #"^\d{1,2}\s+[A-Z][a-zA-Z\s&,]{3,}"#, options: .regularExpression) != nil {
                    // This looks like a new recipe title from the PDF page footer/header
                    // Update lastPotentialTitle so the next "Ingredients" block picks it up
                    let titlePart = line.replacingOccurrences(of: #"^\d{1,2}\s+"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if titlePart.count > 3 {
                        lastPotentialTitle = titlePart
                    }
                }
                currentBlock.append(line)
            }
        }
        if !currentBlock.isEmpty {
            chunks.append(currentBlock)
        }

        // Convert chunks to separator-delimited text
        // Format each chunk so parseRecipeSection can understand it
        var result: [String] = []
        for chunk in chunks {
            let chunkText = chunk.joined(separator: "\n")

            // Extract TITLE line if present
            var chunkLines = chunkText.components(separatedBy: .newlines)
            var title = "Untitled Recipe"
            if let titleLine = chunkLines.first(where: { $0.hasPrefix("TITLE: ") }) {
                title = titleLine.replacingOccurrences(of: "TITLE: ", with: "")
                chunkLines = chunkLines.filter { !$0.hasPrefix("TITLE: ") }
            }

            let formattedChunk = "\(title)\n\n" + chunkLines.joined(separator: "\n")
            result.append(formattedChunk)
        }

        return result.joined(separator: "\n\(separator)\n")
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
    var dietaryTags: [String] = []

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
        self.dietaryTags = recipe.dietaryTags
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

