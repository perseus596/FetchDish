#if os(macOS)
import SwiftUI
import SwiftData

struct MacRootView: View {
    @State private var selectedDestination: AppDestination? = .library
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selected: $selectedDestination)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
                .environment(\.colorScheme, .dark)
        } detail: {
            NavigationStack(path: $navigationPath) {
                Group {
                    switch selectedDestination {
                    case .library, nil:
                        LibraryView()
                    case .addRecipe:
                        ImportView()
                    case .shoppingList:
                        ShoppingListView()
                    case .whatCanICook:
                        WhatCanICookView()
                    case .profile:
                        ProfileView()
                    }
                }
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .library: LibraryView()
                    case .addRecipe: ImportView()
                    case .shoppingList: ShoppingListView()
                    case .whatCanICook: WhatCanICookView()
                    case .profile: ProfileView()
                    }
                }
                .navigationDestination(for: UUID.self) { recipeId in
                    RecipeDetailView(recipeId: recipeId, navigationPath: $navigationPath)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onChange(of: selectedDestination) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}

// MARK: - Sidebar

struct MacSidebarView: View {
    @Binding var selected: AppDestination?
    @AppStorage("appearance") private var appearance: String = "system"
    @Query private var recipes: [Recipe]

    private var isDark: Bool { appearance == "dark" }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background: pantry image + dark overlay
                Image("SidebarBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                Color.black.opacity(0.5)

                // Content
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("FetchDish")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        Text("Just recipes.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                    VStack(spacing: 8) {
                        sidebarButton("My Recipe Library",
                                      subtitle: recipes.isEmpty ? nil : "\(recipes.count) saved",
                                      icon: "book.fill", dest: .library)
                        sidebarButton("Add Recipe", icon: "plus.circle.fill", dest: .addRecipe)
                        sidebarButton("Shopping List", icon: "cart.fill", dest: .shoppingList)
                        sidebarButton("What Can I Cook?", icon: "frying.pan", dest: .whatCanICook)
                        sidebarButton("Profile & Settings", icon: "person.circle.fill", dest: .profile)
                    }
                    .padding(.horizontal, 14)

                    Spacer()

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
                    .padding(.bottom, 20)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
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
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
#endif
