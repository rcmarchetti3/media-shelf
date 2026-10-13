// ItemDetailView.swift
// One item. Replaces frontend/src/pages/ItemDetailPage.tsx.
//
// The cover stands on a plank in front of its own art, blurred, like the
// sleeve propped against the wall. Status and rating are live controls
// right under the title (the brief asked for them near the top, not after
// the metadata). Notes, tags, and season progress edit in a sheet.
//
// Compact: everything stacks. Regular (inner display): cover on the left,
// details on the right, so a half-folded phone shows cover above details.
//
// Edits are sent as a PATCH with explicit nulls for cleared fields, same as
// the web app.

import SwiftUI

struct ItemDetailView: View {
    let itemID: UUID
    var onChange: @MainActor (CollectionItem) -> Void = { _ in }
    var onDelete: @MainActor (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var item: CollectionItem?

    /// Cover beside the details on the inner display, and on any phone
    /// held sideways, where stacking would push the title off screen.
    private var sideBySide: Bool {
        sizeClass == .regular || verticalSizeClass == .compact
    }
    @State private var error: String?
    @State private var showEdit = false
    @State private var confirmDelete = false

    private let api = APIClient.shared

    init(itemID: UUID,
         onChange: @escaping @MainActor (CollectionItem) -> Void = { _ in },
         onDelete: @escaping @MainActor (UUID) -> Void = { _ in }) {
        self.itemID = itemID
        self.onChange = onChange
        self.onDelete = onDelete
    }

    #if DEBUG
    /// Preview only: start with an item instead of fetching one.
    init(preview item: CollectionItem) {
        self.itemID = item.id
        _item = State(initialValue: item)
    }
    #endif

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    if sideBySide {
                        HStack(alignment: .top, spacing: 0) {
                            hero(item).frame(width: sizeClass == .regular ? 360 : 300)
                            details(item).padding(.top, 24)
                        }
                    } else {
                        VStack(spacing: 0) {
                            hero(item)
                            details(item)
                        }
                    }
                }
                .shelfBackground()
            } else if let error {
                ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(error))
                    .shelfBackground()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shelfBackground()
            }
        }
        .navigationTitle(item?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { showEdit = true }
                    .disabled(item == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(item?.isFavorite == true ? "Unfavorite" : "Favorite",
                       systemImage: item?.isFavorite == true ? "heart.fill" : "heart") {
                    Task { await toggleFavorite() }
                }
                .disabled(item == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .disabled(item == nil)
            }
        }
        .sheet(isPresented: $showEdit) {
            if let item {
                EditItemSheet(item: item) { fields in
                    await save(fields)
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { error != nil && item != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(error ?? "")
        }
        .confirmationDialog("Remove from shelf?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await delete() } }
        }
        .task(id: itemID) { await load() }
    }

    // MARK: Hero

    /// The cover on a plank, in front of a blurred, darkened copy of itself.
    private func hero(_ item: CollectionItem) -> some View {
        MediaCover(mediaType: item.mediaType, imageURL: item.imageURL,
                   title: item.title, glow: item.itemStatus?.glow, cornerRadius: 4)
            .frame(maxWidth: sizeClass == .regular ? 220 : 160)
            .padding(.horizontal, 48)
            .padding(.top, 28)
            .padding(.bottom, ShelfPlank.totalHeight - 3)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) { ShelfPlank().padding(.horizontal, 24) }
            // The backdrop is a background, so it can only ever be as tall
            // as the cover and plank. It bleeds up under the nav bar.
            .background {
                backdrop(item)
                    .ignoresSafeArea(edges: .top)
                    // Beside the details, the backdrop is a column, so
                    // dissolve its side and top edges instead of showing a box.
                    .mask {
                        if sideBySide {
                            LinearGradient(
                                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                        .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                startPoint: .leading, endPoint: .trailing)
                            .mask {
                                LinearGradient(
                                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                                    startPoint: .top, endPoint: .bottom)
                            }
                        } else {
                            Color.black
                        }
                    }
            }
    }

    /// The cover's own art, blurred and faded into the wall.
    private func backdrop(_ item: CollectionItem) -> some View {
        GeometryReader { geo in
            RemoteImage(url: item.imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 40)
                        .saturation(1.3)
                        .opacity(0.6)
                } else {
                    Theme.card
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0.2), location: 0),
                        .init(color: Theme.background.opacity(0.6), location: 0.65),
                        .init(color: Theme.background, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Details

    private func details(_ item: CollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            titleBlock(item)
            quickControls(item)

            if item.mediaType == .show, item.currentSeason != nil || item.totalSeasons != nil {
                seasonsCard(item)
            }
            if let about = item.about {
                card("About") {
                    Text(about).font(.subheadline).foregroundStyle(Theme.mutedForeground)
                }
            }
            if let notes = item.notes, !notes.isEmpty {
                card("Notes") {
                    Text(notes).font(.subheadline).foregroundStyle(Theme.foreground)
                }
            }
            if !item.tags.isEmpty {
                card("Tags") {
                    FlowChips(items: item.tags)
                }
            }
            specsCard(item)

            Text(footer(item))
                .font(.caption)
                .foregroundStyle(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    private func titleBlock(_ item: CollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(Theme.heading(.title))
                .foregroundStyle(Theme.foreground)
                .accessibilityIdentifier("detail.title")
            if let byline = item.byline {
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
            }
            HStack(spacing: 8) {
                Chip(text: item.mediaType.singular, systemImage: item.mediaType.symbol)
                if let year = item.year { Chip(text: year) }
                if item.isFavorite { Chip(text: "Favorite", systemImage: "heart.fill", tint: Theme.glowWishlist) }
            }
        }
    }

    /// Stars you tap and a status chip that opens a menu. Both PATCH right away.
    private func quickControls(_ item: CollectionItem) -> some View {
        // Side by side when there's room, stacked when the column is narrow.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                starRating(item)
                Spacer(minLength: 0)
                statusMenu(item)
            }
            VStack(alignment: .leading, spacing: 12) {
                starRating(item)
                statusMenu(item)
            }
        }
        .shelfCard()
    }

    private func starRating(_ item: CollectionItem) -> some View {
        StarRating(rating: item.rating ?? 0) { newValue in
            Task { await save(["rating": newValue == 0 ? .null : .number(Double(newValue))]) }
        }
    }

    private func statusMenu(_ item: CollectionItem) -> some View {
        Menu {
            Picker("Status", selection: Binding(
                get: { item.itemStatus },
                set: { newValue in
                    Task { await save(["status": newValue.map { .string($0.rawValue) } ?? .null]) }
                }
            )) {
                Text("None").tag(ItemStatus?.none)
                ForEach(statusChoices(for: item), id: \.rawValue) { s in
                    Label(s.label, systemImage: s.symbol).tag(ItemStatus?.some(s))
                }
            }
        } label: {
            if let status = item.itemStatus {
                Chip(text: status.label, systemImage: status.symbol, tint: status.tint)
            } else {
                Chip(text: "Set status", systemImage: "circle.dashed")
            }
        }
        .accessibilityLabel("Status")
        .accessibilityValue(item.itemStatus?.label ?? "None")
        .accessibilityIdentifier("detail.status")
    }

    private func seasonsCard(_ item: CollectionItem) -> some View {
        card("Seasons") {
            let current = item.currentSeason ?? 0
            let total = item.totalSeasons ?? max(current, 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("Season \(current) of \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.foreground)
                ProgressView(value: Double(min(current, total)), total: Double(max(total, 1)))
                    .tint(Theme.brass)
            }
        }
    }

    /// The free-form metadata from the source API as a two-column spec
    /// sheet, minus keys shown elsewhere. Same filter as SEASON_KEYS in
    /// statuses.ts, plus ids and the long-form text.
    @ViewBuilder
    private func specsCard(_ item: CollectionItem) -> some View {
        let rows = item.specRows
        if !rows.isEmpty {
            card("Details") {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading),
                                    GridItem(.flexible(), alignment: .topLeading)],
                          alignment: .leading, spacing: 14) {
                    ForEach(rows, id: \.0) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.0.uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.mutedForeground)
                            Text(row.1)
                                .font(.subheadline)
                                .foregroundStyle(Theme.foreground)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.heading(.headline, weight: .semibold))
                .foregroundStyle(Theme.foreground)
            content()
        }
        .shelfCard()
    }

    private func footer(_ item: CollectionItem) -> String {
        var text = "Added \(item.addedAt.formatted(date: .abbreviated, time: .omitted))"
        if let by = item.addedByName { text += " by \(by)" }
        return text
    }

    /// The type's statuses, plus whatever the item already has if it's not
    /// one of them (older data, or a value set from the web).
    private func statusChoices(for item: CollectionItem) -> [ItemStatus] {
        var choices = item.mediaType.statuses
        if let current = item.itemStatus, !choices.contains(current) {
            choices.append(current)
        }
        return choices
    }

    // MARK: Actions

    private func load() async {
        // Previews start with an item and have no server to ask.
        if item != nil, ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        do {
            item = try await api.collectionItem(itemID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Returns true on success so the edit sheet knows whether to dismiss.
    @discardableResult
    private func save(_ fields: [String: JSONValue]) async -> Bool {
        do {
            let updated = try await api.updateCollectionItem(itemID, fields: fields)
            withAnimation(.spring(duration: 0.35)) { item = updated }
            onChange(updated)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func toggleFavorite() async {
        guard let item else { return }
        await save(["is_favorite": .bool(!item.isFavorite)])
    }

    private func delete() async {
        do {
            try await api.deleteCollectionItem(itemID)
            onDelete(itemID)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Derived display fields

private extension CollectionItem {
    static let hiddenSpecKeys: Set<String> = [
        "current_season", "total_seasons", "seasons_count",
        "overview", "description", "tmdb_id", "google_books_id", "genre_ids",
    ]

    /// Long-form text from the source, if any.
    var about: String? {
        let text = (metadata["overview"] ?? metadata["description"])?.displayString
        return text?.isEmpty == false ? text : nil
    }

    /// Artist, author, or director line under the title.
    var byline: String? {
        for key in ["artists", "artist", "authors", "author", "director", "created_by", "creators"] {
            if let text = metadata[key]?.displayString, !text.isEmpty { return text }
        }
        return nil
    }

    var year: String? {
        for key in ["year", "release_date", "first_air_date", "publish_date"] {
            if let text = metadata[key]?.displayString, text.count >= 4 { return String(text.prefix(4)) }
        }
        return nil
    }

    var specRows: [(String, String)] {
        metadata
            .filter { !Self.hiddenSpecKeys.contains($0.key) }
            .compactMap { key, value -> (String, String)? in
                guard let text = value.displayString else { return nil }
                return (key.replacingOccurrences(of: "_", with: " ").capitalized, text)
            }
            .sorted { $0.0 < $1.0 }
    }
}

// MARK: - Controls

/// Five brass stars. Tap to rate; tap the current rating again to clear it.
struct StarRating: View {
    let rating: Int
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    onChange(i == rating ? 0 : i)
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(i <= rating ? Theme.brass : Theme.mutedForeground.opacity(0.6))
                        .symbolEffect(.bounce, value: rating >= i ? rating : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                .accessibilityIdentifier("detail.star.\(i)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rating")
        .accessibilityValue(rating == 0 ? "Not rated" : "\(rating) of 5")
        .accessibilityIdentifier("detail.rating")
    }
}

/// Tags as wrapping chips.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { tag in
                Chip(text: tag)
            }
        }
    }
}

/// Minimal left-to-right wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
#Preview("Detail") {
    NavigationStack {
        ItemDetailView(preview: PreviewData.items[0])
    }
    .tint(Theme.brass)
}
#endif

// MARK: - Edit sheet

/// Notes, tags, and season progress for shows (status and rating are live on
/// the detail screen). Builds the PATCH body with explicit nulls so clearing
/// a field actually clears it.
struct EditItemSheet: View {
    let item: CollectionItem
    var onSave: @MainActor ([String: JSONValue]) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    @State private var tags: String
    @State private var currentSeason: String
    @State private var totalSeasons: String
    @State private var isSaving = false

    init(item: CollectionItem, onSave: @escaping @MainActor ([String: JSONValue]) async -> Bool) {
        self.item = item
        self.onSave = onSave
        _notes = State(initialValue: item.notes ?? "")
        _tags = State(initialValue: item.tags.joined(separator: ", "))
        _currentSeason = State(initialValue: item.currentSeason.map(String.init) ?? "")
        _totalSeasons = State(initialValue: item.totalSeasons.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if item.mediaType == .show {
                    Section("Seasons") {
                        TextField("Current season", text: $currentSeason).keyboardType(.numberPad)
                        TextField("Total seasons", text: $totalSeasons).keyboardType(.numberPad)
                    }
                    .shelfRow()
                }
                Section("Tags") {
                    TextField("Comma separated", text: $tags)
                        .textInputAutocapitalization(.never)
                }
                .shelfRow()
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("edit.notes")
                }
                .shelfRow()
            }
            .shelfBackground()
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var fields: [String: JSONValue] = [
            "notes": notes.isEmpty ? .null : .string(notes),
            "tags": .array(
                tags.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map(JSONValue.string)),
        ]

        if item.mediaType == .show {
            var meta = item.metadata
            meta["current_season"] = Int(currentSeason).map { .number(Double($0)) }
            meta["total_seasons"] = Int(totalSeasons).map { .number(Double($0)) }
            fields["metadata"] = .object(meta)
        }

        if await onSave(fields) { dismiss() }
    }
}
