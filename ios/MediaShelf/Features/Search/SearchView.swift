// SearchView.swift
// The Search tab. Replaces frontend/src/pages/SearchPage.tsx.
//
// Results are covers on shelves, same as the collection, so adding
// something feels like picking it off a store shelf and putting it on
// yours. Already-owned results glow brass with a check.
//
// Compact: tap a cover for a preview sheet with the Add button.
// Regular: results on the left, the selected one's preview on the right.
// The search field itself is the tab bar's (Tab role .search in AppTabView),
// and the media type picker is the search scope bar.

import SwiftUI

struct SearchView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = SearchModel()
    @State private var selected: SearchResult?
    @State private var sheetResult: SearchResult?

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    resultsGrid
                } detail: {
                    if let selected {
                        SearchResultPreview(result: selected, isAdded: model.addedIDs.contains(selected.id)) {
                            await model.add(selected)
                        }
                        .id(selected.id)
                    } else {
                        ContentUnavailableView("Find something to add", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .shelfBackground()
                    }
                }
            } else {
                NavigationStack {
                    resultsGrid
                }
                .sheet(item: $sheetResult) { result in
                    NavigationStack {
                        SearchResultPreview(result: result, isAdded: model.addedIDs.contains(result.id)) {
                            await model.add(result)
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done", systemImage: "xmark") { sheetResult = nil }
                            }
                        }
                    }
                    .presentationDetents([.large])
                }
            }
        }
    }

    /// `.searchable` has to sit on content inside the navigation container;
    /// on the outer Group it never produces a field. Found by the UI tests.
    private var resultsGrid: some View {
        searchResultsContent
            .searchable(text: $model.query, prompt: "Search \(model.mediaType.label.lowercased())")
            .searchScopes($model.mediaType, activation: .onSearchPresentation) {
                ForEach(MediaType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
    }

    private var searchResultsContent: some View {
        ScrollView {
            if !model.results.isEmpty {
                Text(resultsLine)
                    .font(Theme.heading(.title3, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            ShelvedGrid(items: model.results, columns: ShelfGrid.columns(for: sizeClass)) { result in
                Button {
                    if sizeClass == .regular { selected = result } else { sheetResult = result }
                } label: {
                    SearchResultCover(result: result, isAdded: model.addedIDs.contains(result.id))
                }
                .buttonStyle(CoverButtonStyle())
                .accessibilityIdentifier("search.result.\(result.title)")
            }
            .padding(.top, 8)
        }
        .shelfBackground()
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
                SearchWelcome(mediaType: model.mediaType)
            }
        }
    }

    private var resultsLine: String {
        "\(model.results.count) \(model.mediaType.label.lowercased()) for “\(model.query.trimmingCharacters(in: .whitespaces))”"
    }
}

extension SearchResult {
    /// The result's type, falling back to a poster shape for anything unknown.
    var resolvedMediaType: MediaType { MediaType(rawValue: mediaType) ?? .movie }
}

/// A result as a cover on the shelf: title and subtitle on its face, brass
/// glow and a check once it's on your shelf.
struct SearchResultCover: View {
    let result: SearchResult
    let isAdded: Bool

    var body: some View {
        MediaCover(mediaType: result.resolvedMediaType, imageURL: result.imageURL,
                   title: result.title, glow: isAdded ? Theme.glowOwned : nil) {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.oklch(0.93, 0.02, 80))
                if let line = [result.subtitle, result.year].compactMap({ $0 }).first {
                    Text(line)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.oklch(0.72, 0.06, 65))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .padding(.top, 26)
            .background(LinearGradient(
                colors: [.clear, .oklch(0.10, 0.02, 50, alpha: 0.93)],
                startPoint: .top, endPoint: .bottom))
        }
        .overlay(alignment: .topTrailing) {
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.onBrass, Theme.brass)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(5)
                    .accessibilityLabel("On your shelf")
            }
        }
        .contentShape(Rectangle())
    }
}

/// Before anyone has typed: the logo on a shelf and where results come from.
struct SearchWelcome: View {
    let mediaType: MediaType

    private var source: String {
        switch mediaType {
        case .vinyl: "Discogs"
        case .book, .audiobook: "Google Books"
        case .movie, .documentary, .show: "TMDB"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            AppLogo()
                .frame(width: 56, height: 56)
                .padding(.horizontal, 44)
                .padding(.bottom, ShelfPlank.totalHeight - 2)
                .background(alignment: .bottom) { ShelfPlank() }
            VStack(spacing: 6) {
                Text("Find something new")
                    .font(Theme.heading(.title2))
                    .foregroundStyle(Theme.foreground)
                Text("Searching \(source) for \(mediaType.label.lowercased()). Change the type in the scope bar.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Large cover on a plank, metadata, and the Add button. Used as the detail
/// pane on the inner display and as a sheet on the outer one.
struct SearchResultPreview: View {
    let result: SearchResult
    let isAdded: Bool
    var onAdd: @MainActor () async -> Void

    @State private var isAdding = false

    private var about: String? {
        (result.metadata["overview"] ?? result.metadata["description"])?.displayString
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MediaCover(mediaType: result.resolvedMediaType, imageURL: result.imageURL,
                           title: result.title, cornerRadius: 4)
                    .frame(maxWidth: 240)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, ShelfPlank.totalHeight - 3)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .bottom) { ShelfPlank() }

                VStack(spacing: 8) {
                    Text(result.title)
                        .font(Theme.heading(.title2))
                        .foregroundStyle(Theme.foreground)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("preview.title")
                    if let subtitle = result.subtitle, subtitle != result.year {
                        Text(subtitle).foregroundStyle(Theme.mutedForeground)
                    }
                    HStack(spacing: 8) {
                        Chip(text: result.resolvedMediaType.singular, systemImage: result.resolvedMediaType.symbol)
                        if let year = result.year, !year.isEmpty {
                            Chip(text: year)
                        }
                    }
                }
                .padding(.horizontal)

                Button {
                    isAdding = true
                    Task { await onAdd(); isAdding = false }
                } label: {
                    Label(isAdded ? "On your shelf" : "Add to shelf",
                          systemImage: isAdded ? "checkmark" : "plus")
                        .font(.headline)
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdded || isAdding)
                .accessibilityIdentifier("preview.add")

                if let about, !about.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About")
                            .font(Theme.heading(.headline, weight: .semibold))
                            .foregroundStyle(Theme.foreground)
                        Text(about)
                            .font(.subheadline)
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    .shelfCard()
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .shelfBackground()
        .navigationTitle(result.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
