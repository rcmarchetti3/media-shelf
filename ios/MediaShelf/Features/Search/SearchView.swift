// SearchView.swift
// The Search tab. Replaces frontend/src/pages/SearchPage.tsx.
//
// Compact: a list of results, Add button on each row.
// Regular: results on the left, a preview of the selected one on the right.
// The search field itself is the tab bar's (Tab role .search in AppTabView),
// and the media type picker is the search scope bar.

import SwiftUI

struct SearchView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = SearchModel()
    @State private var selected: SearchResult?

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    resultsList
                } detail: {
                    if let selected {
                        SearchResultPreview(result: selected, isAdded: model.addedIDs.contains(selected.id)) {
                            await model.add(selected)
                        }
                    } else {
                        ContentUnavailableView("Find something to add", systemImage: "magnifyingglass")
                    }
                }
            } else {
                NavigationStack {
                    resultsList
                }
            }
        }
        .searchable(text: $model.query, prompt: "Search \(model.mediaType.label.lowercased())")
        .searchScopes($model.mediaType, activation: .onSearchPresentation) {
            ForEach(MediaType.allCases) { type in
                Text(type.label).tag(type)
            }
        }
    }

    private var resultsList: some View {
        List(selection: $selected) {
            ForEach(model.results) { result in
                SearchResultRow(result: result, isAdded: model.addedIDs.contains(result.id)) {
                    await model.add(result)
                }
                .tag(result)
            }
        }
        .navigationTitle("Search")
        .alert("Couldn't add", isPresented: Binding(
            get: { model.addError != nil },
            set: { if !$0 { model.addError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(model.addError ?? "")
        }
        .overlay {
            if model.isSearching, model.results.isEmpty {
                ProgressView()
            } else if let error = model.error, model.results.isEmpty {
                ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if model.results.isEmpty, model.query.count >= 2 {
                ContentUnavailableView.search(text: model.query)
            } else if model.results.isEmpty {
                ContentUnavailableView("Search Discogs, TMDB, and Google Books",
                    systemImage: "magnifyingglass",
                    description: Text("Pick a type in the scope bar, then start typing."))
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let isAdded: Bool
    var onAdd: @MainActor () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.fill.secondary)
            }
            .frame(width: 44, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title).lineLimit(2)
                if let subtitle = result.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                if let year = result.year {
                    Text(year).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if isAdded {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Add", systemImage: "plus.circle") { Task { await onAdd() } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// Inner display only: large cover and metadata for the selected result.
struct SearchResultPreview: View {
    let result: SearchResult
    let isAdded: Bool
    var onAdd: @MainActor () async -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: result.imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Rectangle().fill(.fill.secondary).aspectRatio(2 / 3, contentMode: .fit)
                }
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(result.title).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                if let subtitle = result.subtitle {
                    Text(subtitle).foregroundStyle(.secondary)
                }
                if let year = result.year {
                    Text(year).foregroundStyle(.tertiary)
                }

                Button {
                    Task { await onAdd() }
                } label: {
                    Label(isAdded ? "On your shelf" : "Add to shelf",
                          systemImage: isAdded ? "checkmark" : "plus")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdded)
            }
            .padding()
        }
        .navigationTitle(result.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
