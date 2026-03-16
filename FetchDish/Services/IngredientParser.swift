import Foundation

/// Parses ingredient strings like "2 1/2 cups all-purpose flour, sifted" into structured data.
/// Handles fractions, unicode fractions, mixed numbers, and common unit names.
enum IngredientParser {

    struct Result {
        var amount: Double?
        var unit: String?
        var name: String?
    }

    // MARK: - Unicode fraction map

    private static let unicodeFractions: [Character: Double] = [
        "\u{00BD}": 0.5,    // ½
        "\u{2153}": 1.0/3,  // ⅓
        "\u{2154}": 2.0/3,  // ⅔
        "\u{00BC}": 0.25,   // ¼
        "\u{00BE}": 0.75,   // ¾
        "\u{2155}": 0.2,    // ⅕
        "\u{2156}": 0.4,    // ⅖
        "\u{2157}": 0.6,    // ⅗
        "\u{2158}": 0.8,    // ⅘
        "\u{2159}": 1.0/6,  // ⅙
        "\u{215A}": 5.0/6,  // ⅚
        "\u{215B}": 0.125,  // ⅛
        "\u{215C}": 0.375,  // ⅜
        "\u{215D}": 0.625,  // ⅝
        "\u{215E}": 0.875,  // ⅞
    ]

    // MARK: - Unit aliases

    private static let unitMap: [String: String] = [
        "tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp",
        "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp",
        "cup": "cup", "cups": "cup", "c": "cup",
        "ounce": "oz", "ounces": "oz", "oz": "oz",
        "pound": "lb", "pounds": "lb", "lb": "lb", "lbs": "lb",
        "gram": "g", "grams": "g", "g": "g",
        "kilogram": "kg", "kilograms": "kg", "kg": "kg",
        "milliliter": "ml", "milliliters": "ml", "ml": "ml",
        "liter": "l", "liters": "l", "l": "l",
        "pint": "pint", "pints": "pint", "pt": "pint",
        "quart": "quart", "quarts": "quart", "qt": "quart",
        "gallon": "gallon", "gallons": "gallon", "gal": "gallon",
        "pinch": "pinch", "dash": "dash",
        "clove": "clove", "cloves": "clove",
        "can": "can", "cans": "can",
        "bunch": "bunch", "bunches": "bunch",
        "package": "pkg", "packages": "pkg", "pkg": "pkg",
        "slice": "slice", "slices": "slice",
        "piece": "piece", "pieces": "piece",
        "stick": "stick", "sticks": "stick",
        "head": "head", "heads": "head",
        "sprig": "sprig", "sprigs": "sprig",
        "large": "large", "medium": "medium", "small": "small",
    ]

    // MARK: - Parse

    static func parse(_ input: String) -> Result {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove parenthetical notes like "(about 2 cups)" at the end
        if let range = text.range(of: #"\s*\(.*\)\s*$"#, options: .regularExpression) {
            text = String(text[text.startIndex..<range.lowerBound])
        }

        // Remove trailing comma-separated notes like ", sifted"
        // (keep it simple — only strip if after the main ingredient name)

        var amount: Double?
        var unit: String?
        var name: String?
        var remaining = text

        // Step 1: Extract amount (handles "2", "2.5", "1/2", "2 1/2", "½", "2½")
        (amount, remaining) = extractAmount(from: remaining)

        // Step 2: Extract unit
        let words = remaining.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
        if let firstWord = words.first?.lowercased() {
            // Strip trailing period like "oz."
            let cleanWord = firstWord.hasSuffix(".") ? String(firstWord.dropLast()) : firstWord
            if let normalizedUnit = unitMap[cleanWord] {
                unit = normalizedUnit
                // Check for "of" after unit: "cups of flour" → name = "flour"
                let afterUnit = words.dropFirst()
                if let nextWord = afterUnit.first?.lowercased(), nextWord == "of" {
                    name = afterUnit.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    name = afterUnit.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                // No unit recognized — everything is the name
                name = remaining.trimmingCharacters(in: .whitespaces)
            }
        } else {
            name = remaining.trimmingCharacters(in: .whitespaces)
        }

        // Clean up name
        if let n = name, n.isEmpty { name = nil }

        return Result(amount: amount, unit: unit, name: name)
    }

    // MARK: - Amount extraction

    private static func extractAmount(from text: String) -> (Double?, String) {
        var remaining = text
        var total: Double = 0
        var foundAmount = false

        // Replace unicode fractions with their values
        for (char, value) in unicodeFractions {
            if let idx = remaining.firstIndex(of: char) {
                total += value
                remaining.remove(at: idx)
                foundAmount = true
            }
        }

        remaining = remaining.trimmingCharacters(in: .whitespaces)

        // Match patterns: "2 1/2", "2", "1/2", "2.5"
        let pattern = #"^(\d+)\s+(\d+)\s*/\s*(\d+)"# // mixed number: "2 1/2"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            let whole = Double((remaining as NSString).substring(with: match.range(at: 1))) ?? 0
            let num = Double((remaining as NSString).substring(with: match.range(at: 2))) ?? 0
            let den = Double((remaining as NSString).substring(with: match.range(at: 3))) ?? 1
            total += whole + (den > 0 ? num / den : 0)
            foundAmount = true
            let matchEnd = remaining.index(remaining.startIndex, offsetBy: match.range.length)
            remaining = String(remaining[matchEnd...]).trimmingCharacters(in: .whitespaces)
        } else {
            // Try fraction: "1/2"
            let fracPattern = #"^(\d+)\s*/\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: fracPattern),
               let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
                let num = Double((remaining as NSString).substring(with: match.range(at: 1))) ?? 0
                let den = Double((remaining as NSString).substring(with: match.range(at: 2))) ?? 1
                total += den > 0 ? num / den : 0
                foundAmount = true
                let matchEnd = remaining.index(remaining.startIndex, offsetBy: match.range.length)
                remaining = String(remaining[matchEnd...]).trimmingCharacters(in: .whitespaces)
            } else {
                // Try decimal or whole number: "2.5" or "2"
                let numPattern = #"^(\d+(?:\.\d+)?)"#
                if let regex = try? NSRegularExpression(pattern: numPattern),
                   let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
                    let numStr = (remaining as NSString).substring(with: match.range(at: 1))
                    total += Double(numStr) ?? 0
                    foundAmount = true
                    let matchEnd = remaining.index(remaining.startIndex, offsetBy: match.range.length)
                    remaining = String(remaining[matchEnd...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return (foundAmount ? total : nil, remaining)
    }

    // MARK: - Scaling

    /// Scale an ingredient amount by a multiplier.
    static func scale(amount: Double, by multiplier: Double) -> String {
        let scaled = amount * multiplier

        // Try to express as a clean fraction if close to common ones
        let fractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (1.0/3, "⅓"), (0.375, "⅜"),
            (0.5, "½"), (0.625, "⅝"), (2.0/3, "⅔"), (0.75, "¾"), (0.875, "⅞"),
        ]

        let whole = Int(scaled)
        let frac = scaled - Double(whole)

        if frac < 0.05 {
            return "\(whole)"
        }

        for (value, symbol) in fractions {
            if abs(frac - value) < 0.05 {
                return whole > 0 ? "\(whole)\(symbol)" : symbol
            }
        }

        // Fall back to one decimal
        if scaled == scaled.rounded() {
            return "\(Int(scaled))"
        }
        return String(format: "%.1f", scaled)
    }

    /// Build a display string for a scaled ingredient.
    static func scaledText(ingredient: RecipeIngredient, multiplier: Double) -> String {
        guard let amount = ingredient.amount, multiplier != 1.0 else {
            return ingredient.original
        }
        let scaledAmount = scale(amount: amount, by: multiplier)
        var parts = [scaledAmount]
        if let unit = ingredient.unit { parts.append(unit) }
        if let name = ingredient.name { parts.append(name) }
        return parts.joined(separator: " ")
    }
}
