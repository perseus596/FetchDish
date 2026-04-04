import SwiftUI

/// Shows the parsed recipe for review before saving.
struct RecipePreviewSheet: View {
    let parsed: RecipeParser.ParsedRecipe
    let onSave: (String) -> Void  // passes edited title
    let onCancel: () -> Void

    @State private var editedTitle: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title (editable)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TITLE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Recipe title", text: $editedTitle)
                            .font(.title3.bold())
                    }
                    .padding(.horizontal)

                    // Time info
                    if parsed.prepTime != nil || parsed.cookTime != nil || parsed.totalTime != nil || parsed.servings != nil {
                        HStack(spacing: 16) {
                            if let prep = parsed.prepTime {
                                MetaBadge(icon: "clock", label: "Prep", value: prep)
                            }
                            if let cook = parsed.cookTime {
                                MetaBadge(icon: "flame", label: "Cook", value: cook)
                            }
                            if let total = parsed.totalTime {
                                MetaBadge(icon: "timer", label: "Total", value: total)
                            }
                            if let servings = parsed.servings {
                                MetaBadge(icon: "person.2", label: "Serves", value: "\(servings)")
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // Ingredients
                    if !parsed.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INGREDIENTS (\(parsed.ingredients.count))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(Array(parsed.ingredients.enumerated()), id: \.offset) { _, ingredient in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color("AccentGreen").opacity(0.3))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)
                                    Text(ingredient.original)
                                        .font(.body)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Divider().padding(.horizontal)

                    // Instructions
                    if !parsed.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INSTRUCTIONS (\(parsed.instructions.count) steps)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(Array(parsed.instructions.enumerated()), id: \.offset) { _, instruction in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(instruction.stepNumber)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color("AccentGreen"))
                                        .clipShape(Circle())

                                    Text(instruction.text)
                                        .font(.body)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.top)
            }
            .navigationTitle("Preview Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editedTitle)
                    }
                    .fontWeight(.semibold)
                    .tint(Color("AccentGreen"))
                }
            }
            .onAppear {
                editedTitle = parsed.title
            }
        }
    }
}

struct MetaBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
