import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShoppingListItem.category) private var items: [ShoppingListItem]

    @State private var shoppingVM = ShoppingListViewModel()
    @State private var showClearConfirm = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var navigateToLibrary = false

    @AppStorage("appearance") private var appearance: String = "system"
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        appearance == "dark" || (appearance == "system" && colorScheme == .dark)
    }

    private var groupedItems: [(String, [ShoppingListItem])] {
        let grouped = Dictionary(grouping: items, by: { $0.category })
        return grouped.sorted { $0.key < $1.key }
    }

    private var checkedCount: Int {
        items.filter { $0.isChecked }.count
    }

    private var shoppingBackground: some View {
        ZStack {
            isDark
                ? Color(red: 0.10, green: 0.08, blue: 0.06)
                : Color(red: 1.0, green: 0.98, blue: 0.92)
            Image("ShoppingListBackground")
                .resizable()
                .scaledToFill()
                .opacity(isDark ? 0.15 : 0.5)
        }
        #if os(iOS)
        .ignoresSafeArea()
        #endif
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                shoppingList
            }
        }
        .background { shoppingBackground }
        .navigationTitle("Shopping List")
        .toolbar {
            if !items.isEmpty {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Share
                    Button {
                        let text = shoppingVM.shareText(items: items)
                        #if canImport(UIKit)
                        let ac = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(ac, animated: true)
                        }
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        toastMessage = "Copied to clipboard!"
                        showToast = true
                        #endif
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    // Clear menu
                    Menu {
                        if checkedCount > 0 {
                            Button {
                                shoppingVM.clearCheckedItems(context: modelContext)
                                toastMessage = "Cleared \(checkedCount) items"
                                showToast = true
                                HapticManager.success()
                            } label: {
                                Label("Clear Checked Items", systemImage: "checkmark.circle")
                            }
                        }

                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("Clear Entire List", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Clear entire shopping list?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                shoppingVM.clearAll(context: modelContext)
                toastMessage = "Shopping list cleared"
                showToast = true
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
                    .padding(.bottom, 100)
            }
        }
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("AccentGreen").opacity(0.5))

            Text("Shopping list is empty")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Open any recipe and tap \"Add to Shopping List\" to get started.")
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink(value: AppDestination.library) {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                    Text("Browse Recipes")
                }
                .font(.appSubheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color("AccentGreen"))
                .clipShape(Capsule())
                .shadow(color: Color("AccentGreen").opacity(0.3), radius: 6, y: 3)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shopping List

    private var uncheckedCount: Int {
        items.filter { !$0.isChecked }.count
    }

    private var allChecked: Bool {
        !items.isEmpty && uncheckedCount == 0
    }

    private var shoppingList: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.appSubheadline)
                            .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color(red: 0.2, green: 0.2, blue: 0.2))
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                let newValue = !allChecked
                                for item in items {
                                    item.isChecked = newValue
                                }
                                try? modelContext.save()
                            }
                            HapticManager.selection()
                        } label: {
                            Text(allChecked ? "Deselect All" : "Select All")
                                .font(.appSubheadline)
                                .foregroundStyle(Color("AccentGreen"))
                        }
                    }
                    .listRowBackground(isDark ? Color(red: 0.18, green: 0.14, blue: 0.10).opacity(0.96) : Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.96))
                }

                ForEach(groupedItems, id: \.0) { category, categoryItems in
                    Section(category) {
                        ForEach(categoryItems) { item in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    item.isChecked.toggle()
                                    try? modelContext.save()
                                }
                                HapticManager.selection()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isChecked ? Color("AccentGreen") : (isDark ? Color.white.opacity(0.5) : Color(red: 0.4, green: 0.4, blue: 0.4)))
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.ingredient)
                                            .strikethrough(item.isChecked)
                                            .opacity(item.isChecked ? 0.4 : 1)
                                            .font(.appCallout.weight(.medium))
                                            .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color(red: 0.1, green: 0.1, blue: 0.1))

                                        Text(item.recipeName)
                                            .font(.appFootnote)
                                            .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color(red: 0.35, green: 0.3, blue: 0.25))
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(isDark ? Color(red: 0.18, green: 0.14, blue: 0.10).opacity(0.96) : Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.96))
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                modelContext.delete(categoryItems[offset])
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.clear)

            // Bottom action bar
            if checkedCount > 0 {
                bottomActionBar
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Divider()

            // "All done" banner when every item is checked
            if allChecked {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color("AccentGreen"))
                    Text("All done! Clear the list?")
                        .font(.appSubheadline.weight(.medium))
                }
            }

            HStack(spacing: 10) {
                // Remove checked items
                Button {
                    let count = checkedCount
                    withAnimation {
                        shoppingVM.clearCheckedItems(context: modelContext)
                    }
                    toastMessage = "Removed \(count) item\(count == 1 ? "" : "s")"
                    showToast = true
                    HapticManager.success()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.appSubheadline)
                        Text(allChecked ? "Clear List" : "Remove (\(checkedCount))")
                    }
                    .font(.appSubheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(allChecked ? Color("AccentGreen") : Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Uncheck all — only show when NOT all checked
                if !allChecked {
                    Button {
                        withAnimation {
                            for item in items where item.isChecked {
                                item.isChecked = false
                            }
                            try? modelContext.save()
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.appSubheadline.bold())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom)
        .background(.ultraThinMaterial)
    }
}

