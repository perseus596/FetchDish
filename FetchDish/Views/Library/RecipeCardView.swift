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

                // Allergen warning badge
                if !matchedAllergens.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
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
                        .font(.caption.weight(.semibold))
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
