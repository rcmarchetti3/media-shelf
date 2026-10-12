// ItemDetailView.swift
// One item. Replaces frontend/src/pages/ItemDetailPage.tsx.
//
// Layout is an ArrangementView in split style: cover art is the primary
// view, details and controls the secondary. Fully open on iPhone Duo, cover
// left and details right. Half folded like a book, cover on the top half and
// details on the bottom half. On a compact display it stacks vertically.
// The hinge handling is the container's job; nothing here measures it.
//
// Editing happens in a sheet (EditItemSheet, below) and is sent as a PATCH
// with explicit nulls for cleared fields, same as the web app.

import SwiftUI

struct ItemDetailView: View {
    let itemID: UUID
    var onChange: @MainActor (CollectionItem) -> Void = { _ in }
    var onDelete: @MainActor (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var item: CollectionItem?
    @State private var error: String?
    @State private var showEdit = false
    @State private var confirmDelete = false

    private let api = APIClient.shared

    var body: some View {
        Group {
            if let item {
                ArrangementView {
                    coverPane(item)
                } secondary: {
                    detailsPane(item)
                }
                .arrangementViewStyle(.split)
            } else if let error {
                ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(error))
            } else {
                ProgressView()
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

    // MARK: Panes

    private func coverPane(_ item: CollectionItem) -> some View {
        AsyncImage(url: item.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            default:
                ZStack {
                    Rectangle().fill(.fill.secondary)
                    Image(systemName: item.mediaType.symbol).font(.system(size: 64)).foregroundStyle(.secondary)
                }
                .aspectRatio(item.mediaType.coverAspect, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: (item.itemStatus?.tint ?? .clear).opacity(0.5), radius: 20)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailsPane(_ item: CollectionItem) -> some View {
        List {
            Section {
                LabeledContent("Type", value: item.mediaType.singular)
                if let status = item.itemStatus {
                    LabeledContent("Status") {
                        Label(status.label, systemImage: status.symbol).foregroundStyle(status.tint)
                    }
                }
                if let rating = item.rating {
                    LabeledContent("Rating") {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                            }
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                if item.mediaType == .show, item.currentSeason != nil || item.totalSeasons != nil {
                    LabeledContent("Seasons",
                        value: "\(item.currentSeason.map(String.init) ?? "–") of \(item.totalSeasons.map(String.init) ?? "–")")
                }
            }

            if !item.tags.isEmpty {
                Section("Tags") {
                    Text(item.tags.joined(separator: ", "))
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }

            metadataSection(item)

            Section {
                LabeledContent("Added", value: item.addedAt.formatted(date: .abbreviated, time: .omitted))
                if let by = item.addedByName {
                    LabeledContent("Added by", value: by)
                }
            }
        }
    }

    /// The free-form metadata from the source API, minus keys we show
    /// elsewhere. Same filter as SEASON_KEYS in statuses.ts.
    @ViewBuilder
    private func metadataSection(_ item: CollectionItem) -> some View {
        let hidden: Set<String> = ["current_season", "total_seasons", "seasons_count"]
        let rows = item.metadata
            .filter { !hidden.contains($0.key) }
            .compactMap { key, value -> (String, String)? in
                guard let text = value.displayString else { return nil }
                return (key.replacingOccurrences(of: "_", with: " ").capitalized, text)
            }
            .sorted { $0.0 < $1.0 }
        if !rows.isEmpty {
            Section("Details") {
                ForEach(rows, id: \.0) { row in
                    LabeledContent(row.0, value: row.1)
                }
            }
        }
    }

    // MARK: Actions

    private func load() async {
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
            item = updated
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

// MARK: - Edit sheet

/// Status, rating, notes, tags, and season progress for shows. Builds the
/// PATCH body with explicit nulls so clearing a field actually clears it.
struct EditItemSheet: View {
    let item: CollectionItem
    var onSave: @MainActor ([String: JSONValue]) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var status: ItemStatus?
    @State private var rating: Int
    @State private var notes: String
    @State private var tags: String
    @State private var currentSeason: String
    @State private var totalSeasons: String
    @State private var isSaving = false

    init(item: CollectionItem, onSave: @escaping @MainActor ([String: JSONValue]) async -> Bool) {
        self.item = item
        self.onSave = onSave
        _status = State(initialValue: item.itemStatus)
        _rating = State(initialValue: item.rating ?? 0)
        _notes = State(initialValue: item.notes ?? "")
        _tags = State(initialValue: item.tags.joined(separator: ", "))
        _currentSeason = State(initialValue: item.currentSeason.map(String.init) ?? "")
        _totalSeasons = State(initialValue: item.totalSeasons.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Status", selection: $status) {
                        Text("None").tag(ItemStatus?.none)
                        ForEach(statusChoices, id: \.rawValue) { s in
                            Label(s.label, systemImage: s.symbol).tag(ItemStatus?.some(s))
                        }
                    }
                    Picker("Rating", selection: $rating) {
                        Text("None").tag(0)
                        ForEach(1...5, id: \.self) { n in
                            Text(String(repeating: "★", count: n)).tag(n)
                        }
                    }
                }
                if item.mediaType == .show {
                    Section("Seasons") {
                        TextField("Current season", text: $currentSeason).keyboardType(.numberPad)
                        TextField("Total seasons", text: $totalSeasons).keyboardType(.numberPad)
                    }
                }
                Section("Tags") {
                    TextField("Comma separated", text: $tags)
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 100)
                }
            }
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

    /// The type's statuses, plus whatever the item already has if it's not
    /// one of them (older data, or a value set from the web). Without this
    /// the Picker has no matching tag and shows blank.
    private var statusChoices: [ItemStatus] {
        var choices = item.mediaType.statuses
        if let current = item.itemStatus, !choices.contains(current) {
            choices.append(current)
        }
        return choices
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var fields: [String: JSONValue] = [
            "status": status.map { .string($0.rawValue) } ?? .null,
            "rating": rating == 0 ? .null : .number(Double(rating)),
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
