import SwiftUI
import SwiftData

struct RecipeCardView: View {
    let recipe: Recipe

    @Query(filter: #Predicate<UserAllergen> { $0.isActive == true })
    private var activeAllergens: [UserAllergen]

    #if canImport(UIKit)
    @State private var decodedImage: UIImage?
    #else
    @State private var decodedImage: NSImage?
    #endif

    private var matchedAllergens: [String] {
        let ingredientText = recipe.ingredients.map { $0.original.lowercased() }.joined(separator: " ")
        return activeAllergens.filter { allergen in
            ingredientText.contains(allergen.name.lowercased())
        }.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack {
                Rectangle()
                    .fill(Color("AccentGreen").opacity(0.15))

                if let decodedImage {
                    #if canImport(UIKit)
                    Image(uiImage: decodedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                    #else
                    Image(nsImage: decodedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                    #endif
                } else if recipe.imageData == nil {
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundStyle(Color("AccentGreen").opacity(0.4))
                }

                // Dietary tag badges (top-left)
                if !recipe.dietaryTags.isEmpty {
                    VStack {
                        HStack {
                            HStack(spacing: 3) {
                                ForEach(recipe.dietaryTags.prefix(3), id: \.self) { tag in
                                    Text(DietaryBadgeInfo.abbreviation(for: tag))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(DietaryBadgeInfo.color(for: tag))
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                                }
                                if recipe.dietaryTags.count > 3 {
                                    Text("+\(recipe.dietaryTags.count - 3)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.black.opacity(0.5))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(6)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                // Allergen warning badge
                if !matchedAllergens.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.appCaption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                // Recipe title overlay at bottom
                VStack {
                    Spacer()
                    Text(recipe.title)
                        .font(.appCaption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .frame(height: 140)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .task(id: recipe.id) {
            guard decodedImage == nil, let imageData = recipe.imageData else { return }
            let image = await Task.detached(priority: .userInitiated) {
                #if canImport(UIKit)
                return UIImage(data: imageData)
                #else
                return NSImage(data: imageData)
                #endif
            }.value
            decodedImage = image
        }
    }
}

// MARK: - Dietary Badge Info

enum DietaryBadgeInfo {
    static func abbreviation(for tag: String) -> String {
        switch tag {
        case "Vegan":           return "VG"
        case "Vegetarian":      return "V"
        case "Pescatarian":     return "PSC"
        case "Plant-Based":     return "PB"
        case "Keto":            return "K"
        case "Paleo":           return "PAL"
        case "Whole30":         return "W30"
        case "Low-Carb":        return "LC"
        case "Mediterranean":   return "MED"
        case "Gluten-Free":     return "GF"
        case "Dairy-Free":      return "DF"
        case "Nut-Free":        return "NF"
        case "Sugar-Free":      return "SF"
        case "Halal":           return "HAL"
        case "Kosher":          return "KSH"
        case "Carnivore":       return "CARN"
        case "Raw Food":        return "RF"
        case "Other":           return "+"
        default:                return String(tag.prefix(3)).uppercased()
        }
    }

    static func color(for tag: String) -> Color {
        switch tag {
        case "Vegan", "Vegetarian", "Plant-Based":
            return Color(red: 0.15, green: 0.60, blue: 0.25)
        case "Pescatarian":
            return Color(red: 0.15, green: 0.45, blue: 0.80)
        case "Keto", "Low-Carb":
            return Color(red: 0.80, green: 0.40, blue: 0.10)
        case "Paleo", "Carnivore":
            return Color(red: 0.65, green: 0.25, blue: 0.15)
        case "Whole30", "Raw Food":
            return Color(red: 0.70, green: 0.35, blue: 0.65)
        case "Mediterranean":
            return Color(red: 0.10, green: 0.40, blue: 0.75)
        case "Gluten-Free", "Nut-Free":
            return Color(red: 0.75, green: 0.55, blue: 0.05)
        case "Dairy-Free", "Sugar-Free":
            return Color(red: 0.45, green: 0.20, blue: 0.70)
        case "Halal", "Kosher":
            return Color(red: 0.05, green: 0.50, blue: 0.40)
        default:
            return Color.gray
        }
    }
}
