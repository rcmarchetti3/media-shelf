// ShelfGrid.swift
// The grid of covers. Replaces frontend/src/components/ShelfGrid.tsx.
//
// Column count is even on purpose (2 compact, 4 regular) so the grid splits
// cleanly across the hinge when iPhone Duo is half open. The brief leaves
// 4 vs 6 on the inner display as an open question; change `regularColumns`.
//
// The wooden shelf under each row is a placeholder strip. The design pass
// decides whether it stays literal wood or becomes a tinted glass ledge.

import SwiftUI

struct ShelfGrid: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let items: [CollectionItem]
    var onSelect: @MainActor (CollectionItem) -> Void
    var onReachEnd: @MainActor (CollectionItem) -> Void = { _ in }

    static let regularColumns = 4
    static let compactColumns = 2

    private var columnCount: Int {
        sizeClass == .regular ? Self.regularColumns : Self.compactColumns
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .bottom), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 28) {
            ForEach(items) { item in
                Button { onSelect(item) } label: {
                    ShelfItemView(item: item)
                }
                .buttonStyle(.plain)
                .background(alignment: .bottom) { shelfPlank }
                .onAppear { onReachEnd(item) }
            }
        }
        .padding(.horizontal)
    }

    /// Placeholder "wood". Real texture or glass ledge comes from the design pass.
    private var shelfPlank: some View {
        Rectangle()
            .fill(Color.brown.opacity(0.45))
            .frame(height: 6)
            .offset(y: 10)
    }
}
