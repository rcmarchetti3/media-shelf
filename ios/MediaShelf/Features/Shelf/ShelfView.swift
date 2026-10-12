// ShelfView.swift
// The Shelf tab. Replaces frontend/src/pages/CollectionPage.tsx.
//
// This is the screen that changes most between displays:
//   compact (outer display): NavigationStack, tap a cover to push the detail
//   regular (inner display): NavigationSplitView, grid left, detail right
//
// Filters live in the toolbar as menus. Every item has an icon and a title
// so iOS can draw them on the side of the outer display or fold them into
// the overflow menu. Don't add custom bars here.

import SwiftUI

struct ShelfView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = ShelfModel()
    @State private var selectedID: UUID?
    @State private var path: [UUID] = []

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                stackLayout
            }
        }
        .task { await model.loadIfEmpty() }
    }

    // MARK: Inner display

    private var splitLayout: some View {
        NavigationSplitView {
            grid
                .navigationTitle(title)
                .toolbar { filterToolbar }
        } detail: {
            if let selectedID {
                ItemDetailView(itemID: selectedID, onChange: model.replace, onDelete: { id in
                    model.remove(id: id)
                    self.selectedID = nil
                })
                .id(selectedID)
            } else {
                ContentUnavailableView("Pick something off the shelf", systemImage: "books.vertical")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: Outer display and regular iPhones

    private var stackLayout: some View {
        NavigationStack(path: $path) {
            grid
                .navigationTitle(title)
                .toolbar { filterToolbar }
                .navigationDestination(for: UUID.self) { id in
                    ItemDetailView(itemID: id, onChange: model.replace, onDelete: { id in
                        model.remove(id: id)
                        path.removeAll()
                    })
                }
        }
    }

    // MARK: Shared pieces

    private var title: String {
        model.mediaType?.label ?? "Shelf"
    }

    private var grid: some View {
        ScrollView {
            ShelfGrid(
                items: model.items,
                onSelect: { item in
                    if sizeClass == .regular { selectedID = item.id } else { path.append(item.id) }
                },
                onReachEnd: model.loadMoreIfNeeded(current:))
            .padding(.top)

            if model.isLoading {
                ProgressView().padding()
            }
        }
        .searchable(text: $model.searchText, prompt: "Search your shelf")
        .refreshable { await model.refresh() }
        .overlay {
            if model.items.isEmpty, !model.isLoading {
                if let error = model.error {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(error))
                } else {
                    ContentUnavailableView("Empty shelf", systemImage: "books.vertical",
                        description: Text("Nothing matches these filters."))
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu("Type", systemImage: model.mediaType?.symbol ?? "square.grid.2x2") {
                Picker("Type", selection: $model.mediaType) {
                    Label("All", systemImage: "square.grid.2x2").tag(MediaType?.none)
                    ForEach(MediaType.allCases) { type in
                        Label(type.label, systemImage: type.symbol).tag(MediaType?.some(type))
                    }
                }
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu("Status", systemImage: "checkmark.circle") {
                Picker("Status", selection: $model.status) {
                    Text("Any").tag(ItemStatus?.none)
                    ForEach(model.availableStatuses, id: \.rawValue) { status in
                        Label(status.label, systemImage: status.symbol).tag(ItemStatus?.some(status))
                    }
                }
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Picker("Sort by", selection: $model.sortField) {
                    ForEach(ShelfModel.SortField.allCases) { field in
                        Text(field.label).tag(field)
                    }
                }
                Toggle("Descending", systemImage: "arrow.down", isOn: $model.sortDescending)
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Toggle("Favorites", systemImage: model.favoritesOnly ? "heart.fill" : "heart", isOn: $model.favoritesOnly)
        }
    }
}
