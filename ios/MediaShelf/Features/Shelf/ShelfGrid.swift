// ShelfGrid.swift
// The grid of covers. Replaces frontend/src/components/ShelfGrid.tsx.
//
// ShelvedGrid is the generic piece: any identifiable items, chunked into
// rows, each row standing on a ShelfPlank, same as the web's `.shelf-row`.
// ShelfGrid specializes it for collection items (tap to open, infinite
// scroll, zoom transition). Search uses ShelvedGrid directly.
//
// Columns: the inner display uses an even count (4) so the grid splits
// cleanly across the hinge when iPhone Duo is half open. The outer display
// has no hinge, so it uses 3. The brief leaves 4 vs 6 on the inner display
// as an open question; change `regularColumns`.
//
// Motion: when a row first appears, the plank slides in from the leading
// edge and the covers drop onto it one after another. As rows scroll
// through the viewport they tilt back and dim at the edges, like looking
// along a bookcase.

import SwiftUI

struct ShelfGrid: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let items: [CollectionItem]
    var onSelect: @MainActor (CollectionItem) -> Void
    var onReachEnd: @MainActor (CollectionItem) -> Void = { _ in }
    var zoomNamespace: Namespace.ID? = nil

    static let regularColumns = 4
    static let compactColumns = 3

    static func columns(for sizeClass: UserInterfaceSizeClass?) -> Int {
        sizeClass == .regular ? regularColumns : compactColumns
    }

    var body: some View {
        ShelvedGrid(items: items, columns: Self.columns(for: sizeClass)) { item in
            Button { onSelect(item) } label: {
                ShelfItemView(item: item)
            }
            .buttonStyle(CoverButtonStyle())
            .accessibilityIdentifier("shelf.item.\(item.title)")
            .zoomSource(id: item.id, in: zoomNamespace)
            .onAppear { onReachEnd(item) }
        }
    }
}

// MARK: - Generic shelves

struct ShelvedGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    @ViewBuilder let content: (Item) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Row: Identifiable {
        let items: [Item]
        var id: Item.ID { items[0].id }
    }

    private var rows: [Row] {
        stride(from: 0, to: items.count, by: columns).map { start in
            Row(items: Array(items[start..<min(start + columns, items.count)]))
        }
    }

    var body: some View {
        LazyVStack(spacing: 20) {
            ForEach(rows) { row in
                ShelvedRow(items: row.items, columns: columns, content: content)
                    .scrollTransition(.interactive, axis: .vertical) { view, phase in
                        view
                            .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.94)
                            .opacity(phase.isIdentity ? 1 : 0.55)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * -5),
                                              axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    }
            }
        }
        .padding(.horizontal)
    }
}

/// One shelf: up to `columns` items standing on a plank. Short rows are
/// padded with empty slots so items keep their width.
struct ShelvedRow<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    @ViewBuilder let content: (Item) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .frame(maxWidth: .infinity)
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reduceMotion ? 0 : -36)
                    .animation(entrance.delay(0.15 + Double(index) * 0.07), value: isShown)
            }
            ForEach(0..<max(0, columns - items.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        // Room above for the record that peeks out of a vinyl sleeve. The
        // covers' bottom edge sits a hair into the plank's top surface so
        // they read as standing on it.
        .padding(.top, 12)
        .padding(.bottom, ShelfPlank.totalHeight - 3)
        .background(alignment: .bottom) {
            ShelfPlank()
                .padding(.horizontal, -6)
                .scaleEffect(x: isShown || reduceMotion ? 1 : 0.02, anchor: .leading)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(duration: 0.5, bounce: 0.12), value: isShown)
        }
        .onAppear { isShown = true }
    }

    private var entrance: Animation {
        reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.55, bounce: 0.35)
    }
}

extension View {
    /// Marks this view as the source of a zoom navigation transition when
    /// a namespace is provided; otherwise leaves it alone.
    @ViewBuilder
    func zoomSource(id: UUID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Shelf") {
    NavigationStack {
        ScrollView {
            ShelfGrid(items: PreviewData.items, onSelect: { _ in })
                .padding(.top)
        }
        .shelfBackground()
        .navigationTitle("Shelf")
    }
    .tint(Theme.brass)
}
#endif
