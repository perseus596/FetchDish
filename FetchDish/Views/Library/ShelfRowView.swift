import SwiftUI

struct ShelfRowView: View {
    let recipes: [Recipe]
    let maxPerRow: Int
    let isEditing: Bool
    let onDelete: (Recipe) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Recipe cards row
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(recipes) { recipe in
                    recipeCard(recipe)
                        .frame(maxWidth: .infinity)
                }
                
                // Fill empty slots
                ForEach(0..<max(0, maxPerRow - recipes.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // Shelf plank decoration
            shelfPlank
        }
    }
    
    // MARK: - Recipe Card
    
    @ViewBuilder
    private func recipeCard(_ recipe: Recipe) -> some View {
        if isEditing {
            ZStack(alignment: .topTrailing) {
                RecipeCardView(recipe: recipe)
                    .allowsHitTesting(false)

                Button {
                    onDelete(recipe)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .offset(x: 0, y: -6)
            }
        } else {
            // Normal mode: tappable card for navigation
            NavigationLink(value: recipe.id) {
                RecipeCardView(recipe: recipe)
            }
            .buttonStyle(.plain)
        }
    }

    private var shelfPlank: some View {
        ZStack {
            Image("ProfileShelvesBackground")
                .resizable()
                .scaledToFill()
                .frame(height: 24)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(colorScheme == .dark ? 0.4 : 0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.1 : 0.25), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 2)
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(.black.opacity(colorScheme == .dark ? 0.5 : 0.2))
                    .frame(height: 1)
            }
        }
        .frame(height: 24)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 4, y: 3)
        .allowsHitTesting(false)
    }
}
