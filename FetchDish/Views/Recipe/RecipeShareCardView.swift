import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// The visual recipe card rendered to an image for social sharing.
/// Dimensions: 684×1352 points @2x = 1368×2704px — portrait format.
struct RecipeShareCardView: View {
    let recipe: Recipe

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.2)

    // Card dimensions in points (renders @2x = 1368×2704px)
    static let cardWidth: CGFloat = 684
    static let cardHeight: CGFloat = 1352

    var body: some View {
        ZStack {
            // BACKGROUND — the botanical book texture
            Image("RecipeCardBackground")
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.cardHeight)
                .clipped()

            // Dark overlay for legibility
            Color.black.opacity(0.35)

            // GLASS CARD — floats in center
            VStack(spacing: 0) {
                glassCard
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 60)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipped()
    }

    // MARK: - Glass Card

    private var glassCard: some View {
        VStack(spacing: 0) {
            // Recipe photo or placeholder
            recipePhoto

            // Content area
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(recipe.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                // Stats row
                statsRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.horizontal, 24)

                // Ingredients
                ingredientsList
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                // Footer
                footerBar
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.65),
                        Color.black.opacity(0.80)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }

    // MARK: - Recipe Photo

    @ViewBuilder
    private var recipePhoto: some View {
        if let imageData = recipe.imageData {
            #if canImport(UIKit)
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.cardWidth - 72, height: 280)
                    .clipped()
            } else {
                photoPlaceholder
            }
            #else
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.cardWidth - 72, height: 280)
                    .clipped()
            } else {
                photoPlaceholder
            }
            #endif
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            Color(red: 0.15, green: 0.12, blue: 0.08)
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .frame(width: Self.cardWidth - 72, height: 280)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let prep = recipe.prepTime {
                statPill(icon: "clock", label: "Prep", value: prep)
            }
            if let cook = recipe.cookTime {
                statPill(icon: "flame", label: "Cook", value: cook)
            }
            if let servings = recipe.servings {
                statPill(icon: "person.2", label: "Serves", value: "\(servings)")
            }
            Spacer()
        }
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(gold)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Ingredients List

    private var ingredientsList: some View {
        let topIngredients = recipe.ingredients
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(8)
            .map { ing -> String in
                // Use parsed name if it's meaningful (more than 2 chars)
                if let name = ing.name, name.count > 2 {
                    return name.capitalized
                }
                // Fall back to original, stripping leading quantity/unit
                let stripped = ing.original
                    .replacingOccurrences(of: #"^[\d½¼¾⅓⅔⅛\s,.]+\s*(?:g|kg|ml|l|oz|lb|tsp|tbsp|cup|cups|gr|grams|ounce|ounces|pound|pounds|tablespoon|tablespoons|teaspoon|teaspoons)?\s+"#,
                                         with: "", options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespaces)
                return stripped.isEmpty ? ing.original : stripped.capitalized
            }

        return VStack(alignment: .leading, spacing: 6) {
            Text("INGREDIENTS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(gold)
                .kerning(1.2)
                .padding(.bottom, 2)

            let columns = splitIntoColumns(Array(topIngredients))
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(columns.0, id: \.self) { ing in
                        ingredientRow(ing)
                    }
                }
                if !columns.1.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(columns.1, id: \.self) { ing in
                            ingredientRow(ing)
                        }
                    }
                }
            }

            if recipe.ingredients.count > 8 {
                Text("+ \(recipe.ingredients.count - 8) more ingredients")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 2)
            }
        }
    }

    private func ingredientRow(_ name: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gold.opacity(0.7))
                .frame(width: 4, height: 4)
            Text(name.capitalized)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
        }
    }

    private func splitIntoColumns(_ items: [String]) -> ([String], [String]) {
        let half = Int(ceil(Double(items.count) / 2.0))
        return (Array(items.prefix(half)), Array(items.dropFirst(half)))
    }

    // MARK: - Footer

    private var footerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            VStack(spacing: 16) {
                // White rounded frame containing all branding
                VStack(spacing: 6) {
                    Text("FetchDish")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color.white)

                    Text("No ads. No life stories. Just recipes.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("Get it on the App Store")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(gold)

                    Text("fetchdish.com")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                )

                // Hashtag below the frame
                Text("#FetchDish")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(gold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.4))
        }
    }
}

// MARK: - Renderer

struct RecipeCardRenderer {
    /// Renders the share card to PNG data at @2x scale
    @MainActor
    static func render(recipe: Recipe) -> Data? {
        let cardView = RecipeShareCardView(recipe: recipe)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 2.0
        #if canImport(AppKit)
        return renderer.nsImage.flatMap { img in
            img.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
            }
        }
        #else
        return renderer.uiImage.flatMap { $0.pngData() }
        #endif
    }
}
