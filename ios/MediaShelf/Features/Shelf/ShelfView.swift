// ShelfView.swift
// The Shelf tab. Replaces frontend/src/pages/CollectionPage.tsx.
//
// This is the screen that changes most between displays:
//   compact (outer display): NavigationStack, tap a cover to push the detail
//   regular (inner display): NavigationSplitView, grid left, detail right
//
// Filters live in the toolbar as menus, and the media type also gets a row
// of brass chips at the top of the shelf so switching sections is one tap.
// Every toolbar item has an icon and a title so iOS can draw them on the
// side of the outer display or fold them into the overflow menu.

import SwiftUI

struct ShelfView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppRouter.self) private var router
    @State private var model = ShelfModel()
    @State private var selectedID: UUID?
    @State private var path: [UUID] = []
    @State private var handledRequestID: UUID?
    @Namespace private var coverZoom

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                stackLayout
            }
        }
        .task {
            // Applying a filter already kicks off a load; don't start a second.
            if !applyPendingRequest() {
                await model.loadIfEmpty()
            }
        }
        .onChange(of: router.shelfRequest?.id) { _ = applyPendingRequest() }
    }

    /// A plaque on Home asked for this tab with a filter. Apply it once, and
    /// come back to the grid if a detail screen was open. Returns true if a
    /// request was applied (which reloads the model).
    @discardableResult
    private func applyPendingRequest() -> Bool {
        guard let request = router.shelfRequest, request.id != handledRequestID else { return false }
        handledRequestID = request.id
        path.removeAll()
        selectedID = nil
        model.favoritesOnly = false
        model.searchText = ""
        if model.mediaType == request.mediaType {
            // Same filter as before; the didSet won't fire, so reload by hand.
            model.reload()
        } else {
            model.mediaType = request.mediaType
        }
        return true
    }

    // MARK: Inner display

    private var splitLayout: some View {
        NavigationSplitView {
            grid(zoom: nil)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shelfBackground()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: Outer display and regular iPhones

    /// Tapping a cover zooms it up into the detail screen.
    private var stackLayout: some View {
        NavigationStack(path: $path) {
            grid(zoom: coverZoom)
                .navigationTitle(title)
                .toolbar { filterToolbar }
                .navigationDestination(for: UUID.self) { id in
                    ItemDetailView(itemID: id, onChange: model.replace, onDelete: { id in
                        model.remove(id: id)
                        path.removeAll()
                    })
                    .navigationTransition(.zoom(sourceID: id, in: coverZoom))
                }
        }
    }

    // MARK: Shared pieces

    private var title: String {
        model.mediaType?.label ?? "Shelf"
    }

    /// "127 records · Owned", in the heading face.
    private var countLine: String? {
        guard model.total > 0 else { return nil }
        let noun: String = switch model.mediaType {
        case .vinyl: model.total == 1 ? "record" : "records"
        case .some(let type): model.total == 1 ? type.singular.lowercased() : type.label.lowercased()
        case .none: model.total == 1 ? "item" : "items"
        }
        var line = "\(model.total) \(noun)"
        if let status = model.status { line += " · \(status.label)" }
        if model.favoritesOnly { line += " · Favorites" }
        return line
    }

    private func grid(zoom: Namespace.ID?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                typeChips
                if let countLine {
                    Text(countLine)
                        .font(Theme.heading(.title3, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                        .accessibilityIdentifier("shelf.count")
                        .padding(.horizontal)
                        .contentTransition(.numericText())
                        .animation(.default, value: model.total)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)

            ShelfGrid(
                items: model.items,
                onSelect: { item in
                    if sizeClass == .regular { selectedID = item.id } else { path.append(item.id) }
                },
                onReachEnd: model.loadMoreIfNeeded(current:),
                zoomNamespace: zoom)

            if model.isLoading {
                ProgressView().padding()
            }
        }
        .shelfBackground()
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

    /// All, then one chip per media type. The selected one is brass.
    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TypeChip(label: "All", symbol: "square.grid.2x2", isSelected: model.mediaType == nil) {
                    model.mediaType = nil
                }
                .accessibilityIdentifier("shelf.chip.all")
                ForEach(MediaType.allCases) { type in
                    TypeChip(label: type.label, symbol: type.symbol, isSelected: model.mediaType == type) {
                        model.mediaType = type
                    }
                    .accessibilityIdentifier("shelf.chip.\(type.rawValue)")
                }
            }
            .padding(.horizontal)
        }
        .scrollClipDisabled()
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

/// A brass tag for one media type. Selected: solid brass. Otherwise: card.
struct TypeChip: View {
    let label: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.onBrass : Theme.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.plaqueGradient)
                    } else {
                        Capsule().fill(Theme.card)
                    }
                }
                .overlay(Capsule().strokeBorder(isSelected ? Theme.plaqueBorder : Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 3, y: 2)
        }
        .buttonStyle(PlaqueButtonStyle())
        .animation(.spring(duration: 0.3), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("Chips") {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TypeChip(label: "All", symbol: "square.grid.2x2", isSelected: false) {}
                        ForEach(MediaType.allCases) { type in
                            TypeChip(label: type.label, symbol: type.symbol, isSelected: type == .show) {}
                        }
                    }
                    .padding(.horizontal)
                }
                Text("47 TV shows · Watching")
                    .font(Theme.heading(.title3, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal)
            }
            .padding(.top, 8)
            ShelfGrid(items: PreviewData.items, onSelect: { _ in })
        }
        .shelfBackground()
        .navigationTitle("TV Shows")
    }
    .tint(Theme.brass)
}
#endif
