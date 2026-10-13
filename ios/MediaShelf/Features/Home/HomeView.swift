// HomeView.swift
// The Home tab. Replaces frontend/src/pages/DashboardPage.tsx.
//
// Top to bottom: greeting, a spotlight on the latest addition, brass stat
// plaques (each opens the Shelf tab filtered to that type), the recently
// added shelf, and "You might like" (see Features/Recommendations).
//
// Compact (outer display): plaques in 2 columns. Regular (inner display):
// plaques in one row of 6, bigger covers.

import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var model = HomeModel()
    @State private var recommendations = RecommendationModel()
    @State private var suggestionSheet: Suggestion?
    @Namespace private var coverZoom

    private var statColumns: [GridItem] {
        let count = sizeClass == .regular ? 6 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var firstName: String? {
        auth.user?.displayName.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    if let latest = model.recent.first {
                        SpotlightCard(item: latest, zoomNamespace: coverZoom)
                    }
                    if let stats = model.stats {
                        statsGrid(stats)
                    }
                    recentShelf
                    suggestionShelf
                }
                .padding()
            }
            .shelfBackground()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                async let a: () = model.load()
                async let b: () = recommendations.refresh()
                _ = await (a, b)
            }
            .task { await model.load() }
            .task { await recommendations.loadIfNeeded() }
            .overlay {
                if model.stats == nil && model.isLoading {
                    ProgressView()
                } else if let error = model.error, model.stats == nil {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(error))
                }
            }
            .navigationDestination(for: CollectionItem.self) { item in
                ItemDetailView(itemID: item.id)
                    .navigationTransition(.zoom(sourceID: item.id, in: coverZoom))
            }
            .sheet(item: $suggestionSheet) { suggestion in
                NavigationStack {
                    SearchResultPreview(result: suggestion.result,
                                        isAdded: recommendations.addedIDs.contains(suggestion.id)) {
                        await recommendations.add(suggestion)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "xmark") { suggestionSheet = nil }
                        }
                    }
                }
            }
            .alert("Couldn't add", isPresented: Binding(
                get: { recommendations.addError != nil },
                set: { if !$0 { recommendations.addError = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(recommendations.addError ?? "")
            }
        }
    }

    /// "Welcome back, Rich" in the serif heading face, like the web dashboard.
    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(firstName.map { "Welcome back, \($0)" } ?? "Welcome back")
                .font(Theme.heading(.largeTitle))
                .foregroundStyle(Theme.foreground)
            Text("Here's an overview of your collection.")
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private func statsGrid(_ stats: CollectionStats) -> some View {
        LazyVGrid(columns: statColumns, spacing: 12) {
            ForEach(MediaType.allCases) { type in
                Button {
                    router.showShelf(type)
                } label: {
                    StatTile(type: type, count: stats.count(for: type))
                }
                .buttonStyle(PlaqueButtonStyle())
                .accessibilityIdentifier("home.plaque.\(type.rawValue)")
                .accessibilityHint("Shows \(type.label.lowercased()) on the shelf")
            }
        }
    }

    @ViewBuilder
    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Recently Added")
                Spacer()
                Button("View all") { router.showShelf(nil) }
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .accessibilityIdentifier("home.viewAll")
            }
            if model.recent.isEmpty, !model.isLoading {
                Text("Nothing on the shelf yet. Search to add something.")
                    .foregroundStyle(Theme.mutedForeground)
            } else {
                RecentShelf(items: model.recent, coverWidth: sizeClass == .regular ? 130 : 100,
                            zoomNamespace: coverZoom)
            }
        }
    }

    @ViewBuilder
    private var suggestionShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sectionTitle("You might like")
                if recommendations.rankedOnDevice {
                    Image(systemName: "apple.intelligence")
                        .font(.subheadline)
                        .foregroundStyle(Theme.brass)
                        .accessibilityLabel("Ranked on this phone with Apple Intelligence")
                }
                Spacer()
                if recommendations.phase == .loading {
                    ProgressView().controlSize(.small)
                }
            }
            switch recommendations.phase {
            case .idle, .loading:
                if recommendations.suggestions.isEmpty {
                    Text("Looking through what you've rated…")
                        .foregroundStyle(Theme.mutedForeground)
                } else {
                    suggestionRow
                }
            case .needsRatings:
                Text("Rate a few records or books 4 stars or more and suggestions will show up here.")
                    .foregroundStyle(Theme.mutedForeground)
            case .ready:
                if recommendations.suggestions.isEmpty {
                    Text("Nothing new found from the artists and authors you've rated. Pull to refresh after adding more.")
                        .foregroundStyle(Theme.mutedForeground)
                } else {
                    suggestionRow
                }
            case .failed(let message):
                Text(message).foregroundStyle(Theme.mutedForeground)
            }
        }
    }

    private var suggestionRow: some View {
        SuggestionShelf(suggestions: recommendations.suggestions,
                        addedIDs: recommendations.addedIDs,
                        coverWidth: sizeClass == .regular ? 130 : 104) { suggestion in
            suggestionSheet = suggestion
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.heading(.title2, weight: .semibold))
            .foregroundStyle(Theme.foreground)
    }
}

// MARK: - Spotlight

/// The newest thing on the shelf, propped in front of its own blurred art.
struct SpotlightCard: View {
    let item: CollectionItem
    let zoomNamespace: Namespace.ID

    var body: some View {
        NavigationLink(value: item) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .blur(radius: 28)
                            .saturation(1.3)
                    } else {
                        Theme.plaqueGradient.opacity(0.35)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.15), location: 0),
                            .init(color: .black.opacity(0.75), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom)
                }

                HStack(alignment: .bottom, spacing: 16) {
                    MediaCover(mediaType: item.mediaType, imageURL: item.imageURL,
                               title: item.title, glow: item.itemStatus?.glow)
                        .frame(width: 96)
                        .padding(.horizontal, 10)
                        .padding(.bottom, ShelfPlank.totalHeight - 3)
                        .background(alignment: .bottom) { ShelfPlank() }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Latest addition".uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.brass)
                        Text(item.title)
                            .font(Theme.heading(.title2))
                            .foregroundStyle(Theme.parchment)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.parchment.opacity(0.75))
                            .lineLimit(1)
                        if let status = item.itemStatus {
                            Chip(text: status.label, systemImage: status.symbol, tint: status.tint)
                        }
                    }
                    .padding(.bottom, 4)
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PlaqueButtonStyle())
        .matchedTransitionSource(id: item.id, in: zoomNamespace)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.spotlight")
    }

    private var subtitle: String {
        var text = "\(item.mediaType.singular) · added \(item.addedAt.formatted(.relative(presentation: .named)))"
        if let by = item.addedByName { text += " by \(by)" }
        return text
    }
}

// MARK: - Shelves

/// A single horizontal shelf of covers. The plank spans the full width and
/// stays put; only the covers scroll. Covers drop onto it when it appears.
struct RecentShelf: View {
    let items: [CollectionItem]
    let coverWidth: CGFloat
    let zoomNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        ShelfItemView(item: item).frame(width: coverWidth)
                    }
                    .buttonStyle(CoverButtonStyle())
                    .accessibilityIdentifier("home.recent.\(item.title)")
                    .matchedTransitionSource(id: item.id, in: zoomNamespace)
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reduceMotion ? 0 : -36)
                    .animation(.spring(duration: 0.55, bounce: 0.35).delay(0.15 + Double(min(index, 6)) * 0.07),
                               value: isShown)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, ShelfPlank.totalHeight - 3)
        }
        .scrollClipDisabled()
        .background(alignment: .bottom) {
            ShelfPlank()
                .scaleEffect(x: isShown || reduceMotion ? 1 : 0.02, anchor: .leading)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(duration: 0.5, bounce: 0.12), value: isShown)
        }
        .onAppear { isShown = true }
    }
}

/// Suggested covers on a shelf with a one-line reason under each, as the
/// brief describes. Covers are bottom-aligned to a fixed height so the
/// plank can sit at one known y across mixed aspect ratios.
struct SuggestionShelf: View {
    let suggestions: [Suggestion]
    let addedIDs: Set<String>
    let coverWidth: CGFloat
    var onTap: (Suggestion) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    private var coverHeight: CGFloat { coverWidth / (92 / 136) }
    private let topInset: CGFloat = 12

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    VStack(alignment: .leading, spacing: 10) {
                        Button { onTap(suggestion) } label: {
                            SearchResultCover(result: suggestion.result,
                                              isAdded: addedIDs.contains(suggestion.id))
                                .frame(width: coverWidth)
                        }
                        .buttonStyle(CoverButtonStyle())
                        .accessibilityIdentifier("home.suggestion.\(suggestion.result.title)")
                        .frame(height: coverHeight, alignment: .bottom)
                        .padding(.bottom, ShelfPlank.totalHeight - 3)

                        Text(suggestion.reason)
                            .font(.caption2)
                            .foregroundStyle(Theme.mutedForeground)
                            .lineLimit(3, reservesSpace: true)
                            .frame(width: coverWidth, alignment: .leading)
                    }
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reduceMotion ? 0 : -36)
                    .animation(.spring(duration: 0.55, bounce: 0.35).delay(0.15 + Double(min(index, 6)) * 0.07),
                               value: isShown)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, topInset)
        }
        .scrollClipDisabled()
        .background(alignment: .top) {
            ShelfPlank()
                .offset(y: topInset + coverHeight - 3)
                .scaleEffect(x: isShown || reduceMotion ? 1 : 0.02, anchor: .leading)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(duration: 0.5, bounce: 0.12), value: isShown)
        }
        .onAppear { isShown = true }
    }
}

// MARK: - Plaques

/// One count per media type, as a brass plaque (`.stat-plaque` on the web).
struct StatTile: View {
    let type: MediaType
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(type.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Theme.onBrass.opacity(0.7))
                Spacer(minLength: 4)
                Image(systemName: type.symbol)
                    .font(.caption)
                    .foregroundStyle(Theme.onBrass.opacity(0.6))
            }
            Text(count, format: .number)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.onBrass)
                .contentTransition(.numericText())
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.plaqueGradient, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            // Bevel: light along the top, dark along the bottom.
            RoundedRectangle(cornerRadius: 8)
                .inset(by: 1)
                .strokeBorder(LinearGradient(
                    colors: [.oklch(0.82, 0.10, 80, alpha: 0.4), .clear, .oklch(0.48, 0.08, 64, alpha: 0.35)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.plaqueBorder, lineWidth: 1)
        }
        .shadow(color: .oklch(0.10, 0.02, 50, alpha: 0.35), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }
}

/// Presses a brass plaque into the wall: a touch smaller and dimmer.
struct PlaqueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("Suggestions") {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
            Text("You might like")
                .font(Theme.heading(.title2, weight: .semibold))
                .foregroundStyle(Theme.foreground)
            Image(systemName: "apple.intelligence").foregroundStyle(Theme.brass)
        }
        SuggestionShelf(suggestions: PreviewData.suggestions, addedIDs: [PreviewData.suggestions[1].id],
                        coverWidth: 104) { _ in }
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.background)
}

#Preview("Home pieces") {
    @Previewable @Namespace var ns
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SpotlightCard(item: PreviewData.items[0], zoomNamespace: ns)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(MediaType.allCases.enumerated()), id: \.element) { i, type in
                        Button {} label: { StatTile(type: type, count: [127, 25, 47, 9, 5, 10][i]) }
                            .buttonStyle(PlaqueButtonStyle())
                    }
                }
                Text("Recently Added")
                    .font(Theme.heading(.title2, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                RecentShelf(items: PreviewData.items, coverWidth: 100, zoomNamespace: ns)
                Text("You might like")
                    .font(Theme.heading(.title2, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                SuggestionShelf(suggestions: PreviewData.suggestions, addedIDs: [], coverWidth: 104) { _ in }
            }
            .padding()
        }
        .shelfBackground()
    }
}
#endif
