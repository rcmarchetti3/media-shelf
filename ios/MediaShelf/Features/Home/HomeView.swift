// HomeView.swift
// The Home tab. Replaces frontend/src/pages/DashboardPage.tsx.
//
// Compact (outer display): 2-column stat grid, then a horizontal recent shelf.
// Regular (inner display): stats in one row, bigger recent shelf.
// The "You might like" row from the brief is reserved below recents but
// not built; see Features/Recommendations.

import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = HomeModel()

    private var statColumns: [GridItem] {
        let count = sizeClass == .regular ? 6 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let stats = model.stats {
                        statsGrid(stats)
                    }
                    recentShelf
                }
                .padding()
            }
            .navigationTitle("Home")
            .refreshable { await model.load() }
            .task { await model.load() }
            .overlay {
                if model.stats == nil && model.isLoading {
                    ProgressView()
                } else if let error = model.error, model.stats == nil {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(error))
                }
            }
            .navigationDestination(for: CollectionItem.self) { item in
                ItemDetailView(itemID: item.id)
            }
        }
    }

    private func statsGrid(_ stats: CollectionStats) -> some View {
        LazyVGrid(columns: statColumns, spacing: 12) {
            ForEach(MediaType.allCases) { type in
                StatTile(type: type, count: stats.count(for: type))
            }
        }
    }

    @ViewBuilder
    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently added")
                .font(.title3.weight(.semibold))
            if model.recent.isEmpty, !model.isLoading {
                Text("Nothing on the shelf yet. Search to add something.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(model.recent) { item in
                            NavigationLink(value: item) {
                                ShelfItemView(item: item)
                                    .frame(width: sizeClass == .regular ? 150 : 120)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

/// One count per media type. Placeholder styling; the design pass decides
/// whether these become glass cards or a plain grid.
struct StatTile: View {
    let type: MediaType
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: type.symbol)
                .foregroundStyle(.secondary)
            Text(count, format: .number)
                .font(.title.weight(.semibold))
                .contentTransition(.numericText())
            Text(type.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }
}
