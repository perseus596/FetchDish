import SwiftUI
import SwiftData

enum AppDestination: Hashable {
    case library
    case addRecipe
    case shoppingList
    case whatCanICook
    case profile
}

struct MainMenuView: View {
    @State private var path = NavigationPath()
    @Query private var recipes: [Recipe]
    @AppStorage("appearance") private var appearance: String = "system"

    private var isDark: Bool {
        appearance == "dark"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                menuBackground
                Color.black.opacity(0.2).ignoresSafeArea()
                menuContent
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .library: LibraryView()
                case .addRecipe: ImportView()
                case .shoppingList: ShoppingListView()
                case .whatCanICook: WhatCanICookView()
                case .profile: ProfileView()
                }
            }
            .navigationDestination(for: UUID.self) { recipeId in
                RecipeDetailView(recipeId: recipeId, navigationPath: $path)
            }
        }
    }

    // MARK: - Background (day/night crossfade)

    private var menuBackground: some View {
        ZStack {
            Image("MenuBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(isDark ? 0 : 1)

            Image("MenuBackgroundNight")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(isDark ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.8), value: isDark)
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        VStack(spacing: 0) {
            // Top bar: Day/Night (left) — Profile (right)
            topBar

            Spacer()

            // App title
            VStack(spacing: 6) {
                Text("FetchDish")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                Text("Just recipes.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }

            Spacer()

            // Buttons
            menuButtons

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Day/Night toggle (left)
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    appearance = isDark ? "light" : "dark"
                }
            } label: {
                Image(systemName: isDark ? "moon.stars.fill" : "sun.and.horizon.fill")
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDark ? .cyan : Color(red: 1.0, green: 0.85, blue: 0.2))
                    .frame(width: 44, height: 44)
                    .background {
                        ZStack {
                            Circle().fill(.black.opacity(0.2))
                            Circle().fill(.ultraThinMaterial.opacity(0.5))
                            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                        }
                    }
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Profile (right)
            Button {
                path.append(AppDestination.profile)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.body)
                    Text("Profile")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    ZStack {
                        Capsule().fill(.black.opacity(0.2))
                        Capsule().fill(.ultraThinMaterial.opacity(0.5))
                        Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                    }
                }
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 32)
    }

    // MARK: - Menu Buttons

    private var menuButtons: some View {
        VStack(spacing: 14) {
            menuButton(
                title: "My Recipe Library",
                subtitle: recipes.isEmpty ? nil : "\(recipes.count) saved",
                icon: "book.fill",
                destination: .library
            )
            .frame(height: 72)

            HStack(spacing: 14) {
                menuButton(
                    title: "Add Recipe",
                    subtitle: nil,
                    icon: "plus.circle.fill",
                    destination: .addRecipe
                )
                menuButton(
                    title: "Shopping List",
                    subtitle: nil,
                    icon: "cart.fill",
                    destination: .shoppingList
                )
            }
            .frame(height: 62)

            menuButton(
                title: "What Can I Cook?",
                subtitle: nil,
                icon: "frying.pan",
                destination: .whatCanICook
            )
            .frame(height: 62)
        }
    }

    // MARK: - Button Style (clear glass)

    @ViewBuilder
    private func menuButton(title: String, subtitle: String?, icon: String, destination: AppDestination) -> some View {
        Button {
            path.append(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    // Very subtle dark tint (more transparent than before)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.15))

                    // Thin glass material at low opacity
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.4))

                    // Light top edge highlight
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.15),
                                    .clear,
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Border glow
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.35),
                                    .white.opacity(0.08),
                                    .white.opacity(0.03),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
