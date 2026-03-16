import SwiftUI
import SwiftData

@main
struct FetchDishApp: App {
    @AppStorage("appearance") private var appearance: String = "system"
    @State private var showSplash = true

    static func createContainer() -> ModelContainer {
        let schema = Schema([
            Recipe.self,
            RecipeIngredient.self,
            RecipeInstruction.self,
            ShoppingListItem.self,
            FavoriteIngredient.self,
            UserAllergen.self,
            UserDietaryPreference.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("SwiftData container error:", error)
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = Self.createContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                } else {
                    #if os(macOS)
                    MacRootView()
                    #else
                    MainMenuView()
                    #endif
                }
            }
            .preferredColorScheme(colorScheme)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 700)
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

// MARK: - Mac Root View

#if os(macOS)
struct MacRootView: View {
    @State private var selectedDestination: AppDestination? = .library
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selected: $selectedDestination)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            NavigationStack(path: $navigationPath) {
                Group {
                    switch selectedDestination {
                    case .library, nil: LibraryView()
                    case .addRecipe:    ImportView()
                    case .shoppingList: ShoppingListView()
                    case .whatCanICook: WhatCanICookView()
                    case .profile:      ProfileView()
                    }
                }
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .library:      LibraryView()
                    case .addRecipe:    ImportView()
                    case .shoppingList: ShoppingListView()
                    case .whatCanICook: WhatCanICookView()
                    case .profile:      ProfileView()
                    }
                }
                .navigationDestination(for: UUID.self) { recipeId in
                    RecipeDetailView(recipeId: recipeId, navigationPath: $navigationPath)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbarColorScheme(.light, for: .windowToolbar)
        .onChange(of: selectedDestination) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}

struct MacSidebarView: View {
    @Binding var selected: AppDestination?
    @AppStorage("appearance") private var appearance: String = "system"
    @Query private var recipes: [Recipe]

    private var isDark: Bool { appearance == "dark" }

    var body: some View {
        List {
            // Branding header
            VStack(spacing: 4) {
                Text("FetchDish")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                Text("Just recipes.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Nav buttons
            sidebarButton("My Recipe Library",
                          subtitle: recipes.isEmpty ? nil : "\(recipes.count) saved",
                          icon: "book.fill", dest: .library)
            sidebarButton("Add Recipe",         icon: "plus.circle.fill",  dest: .addRecipe)
            sidebarButton("Shopping List",      icon: "cart.fill",          dest: .shoppingList)
            sidebarButton("What Can I Cook?",   icon: "frying.pan",         dest: .whatCanICook)
            sidebarButton("Profile & Settings", icon: "person.circle.fill", dest: .profile)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Image("SidebarBackground")
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.55)
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            // Day/Night toggle pinned to bottom
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    appearance = isDark ? "light" : "dark"
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isDark ? "moon.stars.fill" : "sun.and.horizon.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isDark ? .cyan : Color(red: 1.0, green: 0.85, blue: 0.2))
                    Text(isDark ? "Night Mode" : "Day Mode")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .background(Color.clear)
        }
    }

    @ViewBuilder
    private func sidebarButton(_ title: String, subtitle: String? = nil,
                                icon: String, dest: AppDestination) -> some View {
        let isSelected = selected == dest
        Button { selected = dest } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.body).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if let subtitle {
                        Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.4 : 0.15), lineWidth: 0.7))
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
#endif

