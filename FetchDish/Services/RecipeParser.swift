import Foundation
import SwiftSoup

/// The heart of FetchDish — fetches a URL and extracts the recipe data.
/// Priority: JSON-LD → Microdata → WordPress plugins → Heuristic HTML parsing.
actor RecipeParser {

    // MARK: - CORS Proxies (needed for macOS; iOS can fetch directly in most cases)

    private static let corsProxies: [(String) -> String] = [
        { url in "https://api.allorigins.win/raw?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)" },
        { url in "https://corsproxy.io/?\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)" },
    ]

    // MARK: - Public API

    struct ParsedRecipe {
        var title: String
        var description: String?
        var sourceUrl: String?
        var imageUrl: String?
        var prepTime: String?
        var cookTime: String?
        var totalTime: String?
        var servings: Int?
        var ingredients: [ParsedIngredient]
        var instructions: [ParsedInstruction]
        var notes: String?
        var calories: String?
        var fat: String?
        var carbs: String?
        var protein: String?
        var fiber: String?
        var sugar: String?
        var cuisine: String?
    }

    struct ParsedIngredient {
        var original: String
        var amount: Double?
        var unit: String?
        var name: String?
    }

    struct ParsedInstruction {
        var stepNumber: Int
        var text: String
    }

    /// Fetch and parse a recipe from a URL.
    func fetchAndParse(url: String) async throws -> ParsedRecipe {
        let html = try await fetchHTML(url: url)

        // 1. Try JSON-LD (works on ~90% of recipe sites)
        if let recipe = parseJsonLd(html: html, sourceUrl: url) {
            return recipe
        }

        // 2. Try WordPress recipe plugin patterns via SwiftSoup
        if let recipe = parseWordPressPlugins(html: html, sourceUrl: url) {
            return recipe
        }

        // 3. Heuristic HTML parsing
        if let recipe = parseHeuristic(html: html, sourceUrl: url) {
            return recipe
        }

        throw ParseError.noRecipeFound
    }

    /// Download an image from a URL and return the data.
    func fetchImageData(url: String) async -> Data? {
        guard let imageUrl = URL(string: url) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            return data
        } catch {
            // Try via proxy as fallback
            for proxyFn in Self.corsProxies {
                let proxied = proxyFn(url)
                guard let proxyUrl = URL(string: proxied) else { continue }
                do {
                    let (data, _) = try await URLSession.shared.data(from: proxyUrl)
                    return data
                } catch {
                    continue
                }
            }
            return nil
        }
    }

    // MARK: - Errors

    enum ParseError: LocalizedError {
        case invalidUrl
        case fetchFailed
        case noRecipeFound

        var errorDescription: String? {
            switch self {
            case .invalidUrl:
                return "That doesn't look like a valid URL. Check it and try again."
            case .fetchFailed:
                return "Couldn't reach that site. Check the URL and try again."
            case .noRecipeFound:
                return "Couldn't find a recipe on that page. Try a different URL, or add it manually."
            }
        }
    }

    // MARK: - Fetching

    /// Builds a URLRequest that mimics a real Safari browser to avoid blocks.
    private func browserRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://www.google.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 30
        request.httpShouldHandleCookies = true
        return request
    }

    /// Decode response data to a String, trying multiple encodings.
    private func decodeHTML(data: Data) -> String? {
        if let html = String(data: data, encoding: .utf8), !html.isEmpty { return html }
        if let html = String(data: data, encoding: .isoLatin1), !html.isEmpty { return html }
        if let html = String(data: data, encoding: .windowsCP1252), !html.isEmpty { return html }
        return nil
    }

    private func fetchHTML(url: String) async throws -> String {
        // Strip fragment (e.g. #recipe) — it's client-side only
        let cleanUrl = url.components(separatedBy: "#").first ?? url

        // Configure a session that follows redirects and stores cookies
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.httpCookieAcceptPolicy = .always
        sessionConfig.httpShouldSetCookies = true
        let session = URLSession(configuration: sessionConfig)

        // Try direct fetch first
        if let directUrl = URL(string: cleanUrl) {
            do {
                let request = browserRequest(url: directUrl)
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    // Accept 200-299 responses
                    if (200...299).contains(httpResponse.statusCode),
                       let html = decodeHTML(data: data) {
                        return html
                    }
                    // Some sites return 403/503 with a cookie-set redirect — retry once
                    if [403, 503].contains(httpResponse.statusCode) {
                        try? await Task.sleep(for: .seconds(1))
                        let retryRequest = browserRequest(url: directUrl)
                        let (retryData, retryResponse) = try await session.data(for: retryRequest)
                        if let retryHttp = retryResponse as? HTTPURLResponse,
                           (200...299).contains(retryHttp.statusCode),
                           let html = decodeHTML(data: retryData) {
                            return html
                        }
                    }
                }
            } catch {
                // Fall through to proxy
            }
        }

        // Try CORS proxies as fallback
        for proxyFn in Self.corsProxies {
            let proxied = proxyFn(cleanUrl)
            guard let proxyUrl = URL(string: proxied) else { continue }
            do {
                var request = URLRequest(url: proxyUrl)
                request.timeoutInterval = 30
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let html = decodeHTML(data: data) {
                    return html
                }
            } catch {
                continue
            }
        }

        throw ParseError.fetchFailed
    }

    // MARK: - 1. JSON-LD Parsing

    private func parseJsonLd(html: String, sourceUrl: String) -> ParsedRecipe? {
        // Extract all <script type="application/ld+json"> blocks
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let jsonString = nsHTML.substring(with: match.range(at: 1))
            guard let jsonData = jsonString.data(using: .utf8) else { continue }

            do {
                let json = try JSONSerialization.jsonObject(with: jsonData)
                if let recipeDict = findRecipeInJson(json) {
                    return recipeFromDict(recipeDict, sourceUrl: sourceUrl)
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func findRecipeInJson(_ json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if let type = dict["@type"] {
                if let typeStr = type as? String, typeStr == "Recipe" { return dict }
                if let typeArr = type as? [String], typeArr.contains("Recipe") { return dict }
            }
            // Check @graph
            if let graph = dict["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let found = findRecipeInJson(item) { return found }
                }
            }
        }
        if let arr = json as? [Any] {
            for item in arr {
                if let found = findRecipeInJson(item) { return found }
            }
        }
        return nil
    }

    private func recipeFromDict(_ dict: [String: Any], sourceUrl: String) -> ParsedRecipe {
        let ingredients = parseSchemaIngredients(dict["recipeIngredient"])
        let instructions = parseSchemaInstructions(dict["recipeInstructions"])
        let nutrition = dict["nutrition"] as? [String: Any]

        // Clean description: strip HTML tags and limit length
        let rawDescription = dict["description"] as? String
        let cleanDescription = rawDescription.map { stripHTML($0) }
        let trimmedDescription = cleanDescription.map { String($0.prefix(500)) }

        return ParsedRecipe(
            title: stripHTML(dict["name"] as? String ?? "Untitled Recipe"),
            description: trimmedDescription,
            sourceUrl: sourceUrl,
            imageUrl: extractImageUrl(dict["image"]),
            prepTime: parseDuration(dict["prepTime"] as? String),
            cookTime: parseDuration(dict["cookTime"] as? String),
            totalTime: parseDuration(dict["totalTime"] as? String),
            servings: parseServings(dict["recipeYield"]),
            ingredients: ingredients,
            instructions: instructions,
            notes: nil,
            calories: nutrition?["calories"] as? String,
            fat: nutrition?["fatContent"] as? String,
            carbs: nutrition?["carbohydrateContent"] as? String,
            protein: nutrition?["proteinContent"] as? String,
            fiber: nutrition?["fiberContent"] as? String,
            sugar: nutrition?["sugarContent"] as? String,
            cuisine: extractCuisine(dict["recipeCuisine"])
        )
    }

    private func parseSchemaIngredients(_ value: Any?) -> [ParsedIngredient] {
        guard let arr = value as? [String] else { return [] }
        return arr.compactMap { str in
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let parsed = IngredientParser.parse(trimmed)
            return ParsedIngredient(original: trimmed, amount: parsed.amount, unit: parsed.unit, name: parsed.name)
        }
    }

    private func parseSchemaInstructions(_ value: Any?) -> [ParsedInstruction] {
        guard let arr = value as? [Any] else { return [] }
        var result: [ParsedInstruction] = []
        var stepNum = 1

        for item in arr {
            if let str = item as? String {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(ParsedInstruction(stepNumber: stepNum, text: trimmed))
                    stepNum += 1
                }
            } else if let dict = item as? [String: Any] {
                let type = dict["@type"] as? String ?? ""
                if type == "HowToStep" {
                    let raw = (dict["text"] as? String) ?? (dict["name"] as? String) ?? ""
                    let trimmed = stripHTML(raw)
                    if !trimmed.isEmpty {
                        result.append(ParsedInstruction(stepNumber: stepNum, text: trimmed))
                        stepNum += 1
                    }
                } else if type == "HowToSection" {
                    if let items = dict["itemListElement"] as? [Any] {
                        for subItem in items {
                            if let subDict = subItem as? [String: Any] {
                                let raw = (subDict["text"] as? String) ?? (subDict["name"] as? String) ?? ""
                                let trimmed = stripHTML(raw)
                                if !trimmed.isEmpty {
                                    result.append(ParsedInstruction(stepNumber: stepNum, text: trimmed))
                                    stepNum += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    // MARK: - 2. WordPress / Recipe Plugin Parsing

    private func parseWordPressPlugins(html: String, sourceUrl: String) -> ParsedRecipe? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }

        // Each config: (container, title, ingredients, instructions)
        // Ordered by popularity — most common plugins first.
        let configs: [(container: String, title: String, ingredients: String, instructions: String)] = [
            // WP Recipe Maker (WPRM) — multiple selector variations
            (".wprm-recipe-container", ".wprm-recipe-name", ".wprm-recipe-ingredient", ".wprm-recipe-instruction-text"),
            (".wprm-recipe", ".wprm-recipe-name", ".wprm-recipe-ingredient", ".wprm-recipe-instruction-text"),
            // Tasty Recipes (Mediavine)
            (".tasty-recipes", ".tasty-recipes-title", ".tasty-recipe-ingredients li", ".tasty-recipe-instructions li"),
            // Mediavine Create
            (".mv-recipe-card, .mv-create-card", ".mv-create-title, .mv-recipe-title", ".mv-create-ingredients li", ".mv-create-instructions li"),
            // WP Delicious (formerly Jeebees / WP Starter)
            (".wpd-recipe, .wpdelicious-recipe", ".wpd-recipe-title, .wpdelicious-recipe-title", ".wpd-ingredient, .wpdelicious-ingredient", ".wpd-instruction, .wpdelicious-instruction"),
            // Recipe Card Blocks (by developer FLAVOR)
            (".recipe-card-block, .wp-block-flavor-recipe-card", "h2.recipe-card-title", ".recipe-card-ingredients li, .ingredients-list li", ".recipe-card-instructions li, .instructions-list li"),
            // Jeebees / ZipRecipes
            (".zlrecipe-container, .zip-recipe-plugin", ".zlrecipe-title, .zip-recipe-title", ".zlrecipe-ingredients li, .ingredients li", ".zlrecipe-instructions li, .instructions li"),
            // EasyRecipe
            (".easyrecipe", ".ERSName", ".ERSIngredients li", ".ERSInstructions li"),
            // Yummly / Generic
            (".recipe-card", ".recipe-card-title, .recipe-title, h2", ".recipe-ingredients li, .ingredients li", ".recipe-instructions li, .instructions li, .directions li"),
            // Simple Recipe Pro
            (".simmer-recipe, .srp-recipe", ".simmer-recipe-title, .srp-recipe-title", ".simmer-recipe-ingredients li, .srp-ingredients li", ".simmer-recipe-instructions li, .srp-instructions li"),
        ]

        for config in configs {
            guard let container = try? doc.select(config.container).first() else { continue }

            let titleEl = try? container.select(config.title).first()
            let ingredientEls = (try? container.select(config.ingredients)) ?? Elements()
            let instructionEls = (try? container.select(config.instructions)) ?? Elements()

            guard ingredientEls.size() > 0 || instructionEls.size() > 0 else { continue }

            let ingredients: [ParsedIngredient] = ingredientEls.compactMap { el in
                guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return nil }
                let parsed = IngredientParser.parse(text)
                return ParsedIngredient(original: text, amount: parsed.amount, unit: parsed.unit, name: parsed.name)
            }

            var stepNum = 1
            let instructions: [ParsedInstruction] = instructionEls.compactMap { el in
                guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return nil }
                let inst = ParsedInstruction(stepNumber: stepNum, text: text)
                stepNum += 1
                return inst
            }

            // Try multiple image sources
            let imgEl = try? container.select("img").first()
                ?? doc.select(".wprm-recipe-image img, .tasty-recipes-image img, .mv-create-image img").first()
            var imageUrl = try? imgEl?.attr("data-lazy-src")  // lazy-loaded images
            if imageUrl == nil || imageUrl?.isEmpty == true {
                imageUrl = try? imgEl?.attr("data-src")  // another lazy pattern
            }
            if imageUrl == nil || imageUrl?.isEmpty == true {
                imageUrl = try? imgEl?.attr("src")
            }

            // Try to extract servings, prep/cook time from the plugin container
            let servingsEl = try? container.select(".wprm-recipe-servings, .tasty-recipes-yield, .mv-create-yield, .servings, .recipe-yield").first()
            let servingsText = try? servingsEl?.text()
            let servings = servingsText.flatMap { parseServings($0) }

            let prepEl = try? container.select(".wprm-recipe-prep_time-container, .tasty-recipes-prep-time, .prep-time").first()
            let cookEl = try? container.select(".wprm-recipe-cook_time-container, .tasty-recipes-cook-time, .cook-time").first()
            let totalEl = try? container.select(".wprm-recipe-total_time-container, .tasty-recipes-total-time, .total-time").first()

            return ParsedRecipe(
                title: (try? titleEl?.text()) ?? "Untitled Recipe",
                description: nil,
                sourceUrl: sourceUrl,
                imageUrl: imageUrl,
                prepTime: try? prepEl?.text(),
                cookTime: try? cookEl?.text(),
                totalTime: try? totalEl?.text(),
                servings: servings,
                ingredients: ingredients,
                instructions: instructions,
                notes: nil,
                calories: nil, fat: nil, carbs: nil, protein: nil, fiber: nil, sugar: nil
            )
        }
        return nil
    }

    // MARK: - 3. Heuristic Parsing

    private func parseHeuristic(html: String, sourceUrl: String) -> ParsedRecipe? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }

        let headings = (try? doc.select("h1, h2, h3, h4, h5, h6")) ?? Elements()

        var ingredientHeading: Element?
        var instructionHeading: Element?

        for heading in headings {
            guard let text = try? heading.text().lowercased() else { continue }
            if text.contains("ingredient") && ingredientHeading == nil {
                ingredientHeading = heading
            }
            if (text.contains("instruction") || text.contains("direction") || text.contains("method") || text.contains("step")) && instructionHeading == nil {
                instructionHeading = heading
            }
        }

        var ingredients: [ParsedIngredient] = []
        var instructions: [ParsedInstruction] = []

        // Get list items after ingredients heading
        if let heading = ingredientHeading {
            var sibling = try? heading.nextElementSibling()
            while let el = sibling {
                let tag = el.tagName().uppercased()
                if ["H1", "H2", "H3", "H4", "H5", "H6"].contains(tag) { break }
                if tag == "UL" || tag == "OL" {
                    let items = (try? el.select("li")) ?? Elements()
                    for li in items {
                        if let text = try? li.text().trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                            let parsed = IngredientParser.parse(text)
                            ingredients.append(ParsedIngredient(original: text, amount: parsed.amount, unit: parsed.unit, name: parsed.name))
                        }
                    }
                    break
                }
                sibling = try? el.nextElementSibling()
            }
        }

        // Get list items after instructions heading
        if let heading = instructionHeading {
            var sibling = try? heading.nextElementSibling()
            var stepNum = 1
            while let el = sibling {
                let tag = el.tagName().uppercased()
                if ["H1", "H2", "H3", "H4", "H5", "H6"].contains(tag) { break }
                if tag == "OL" || tag == "UL" {
                    let items = (try? el.select("li")) ?? Elements()
                    for li in items {
                        if let text = try? li.text().trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                            instructions.append(ParsedInstruction(stepNumber: stepNum, text: text))
                            stepNum += 1
                        }
                    }
                    break
                }
                if tag == "P" {
                    if let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines), text.count > 20 {
                        instructions.append(ParsedInstruction(stepNumber: stepNum, text: text))
                        stepNum += 1
                    }
                }
                sibling = try? el.nextElementSibling()
            }
        }

        guard !ingredients.isEmpty || !instructions.isEmpty else { return nil }

        let title = (try? doc.select("h1").first()?.text())
            ?? (try? doc.title())
            ?? "Untitled Recipe"

        return ParsedRecipe(
            title: title,
            description: nil,
            sourceUrl: sourceUrl,
            imageUrl: nil,
            prepTime: nil, cookTime: nil, totalTime: nil,
            servings: nil,
            ingredients: ingredients,
            instructions: instructions,
            notes: nil,
            calories: nil, fat: nil, carbs: nil, protein: nil, fiber: nil, sugar: nil
        )
    }

    // MARK: - Helpers

    /// Remove HTML tags and decode common entities from text.
    private func stripHTML(_ text: String) -> String {
        var result = text
        // Remove HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&#8217;", "\u{2019}"), ("&#8220;", "\u{201C}"), ("&#8221;", "\u{201D}"),
            ("&nbsp;", " "), ("&#8211;", "\u{2013}"), ("&#8212;", "\u{2014}"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Collapse whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractCuisine(_ value: Any?) -> String? {
        if let str = value as? String {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let arr = value as? [String], let first = arr.first {
            return first.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractImageUrl(_ value: Any?) -> String? {
        if let str = value as? String { return str }
        if let arr = value as? [Any], let first = arr.first { return extractImageUrl(first) }
        if let dict = value as? [String: Any] {
            return dict["url"] as? String ?? dict["contentUrl"] as? String
        }
        return nil
    }

    private func parseDuration(_ iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso)) else {
            return nil
        }

        let hoursStr = match.range(at: 1).location != NSNotFound
            ? (iso as NSString).substring(with: match.range(at: 1)) : nil
        let minsStr = match.range(at: 2).location != NSNotFound
            ? (iso as NSString).substring(with: match.range(at: 2)) : nil

        let hours = hoursStr.flatMap { Int($0) } ?? 0
        let mins = minsStr.flatMap { Int($0) } ?? 0

        if hours > 0 && mins > 0 { return "\(hours) hr \(mins) min" }
        if hours > 0 { return "\(hours) hr" }
        if mins > 0 { return "\(mins) min" }
        return nil
    }

    private func parseServings(_ value: Any?) -> Int? {
        if let num = value as? Int { return num }
        if let str = value as? String {
            // Extract first number from strings like "4 servings" or "4-6"
            let pattern = #"(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) {
                let numStr = (str as NSString).substring(with: match.range(at: 1))
                return Int(numStr)
            }
        }
        if let arr = value as? [Any], let first = arr.first {
            return parseServings(first)
        }
        return nil
    }
}
