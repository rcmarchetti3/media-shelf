// ShelfItemView.swift
// One cover on the shelf. Replaces frontend/src/components/ShelfItem.tsx.
//
// Placeholder look: cover with a status-tinted glow, title underneath, small
// status mark and favorite heart. The wooden shelf itself is drawn by
// ShelfGrid, not here. The design pass owns what this ends up looking like;
// keep the data it shows the same.

import SwiftUI

struct ShelfItemView: View {
    let item: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var cover: some View {
        AsyncImage(url: item.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Rectangle().fill(.fill.secondary)
                    Image(systemName: item.mediaType.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(item.mediaType.coverAspect, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: glowColor.opacity(0.6), radius: 8)
        .overlay(alignment: .topTrailing) {
            if item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .padding(5)
                    .foregroundStyle(.pink)
                    .background(.thinMaterial, in: Circle())
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let status = item.itemStatus {
                Image(systemName: status.symbol)
                    .font(.caption2.weight(.bold))
                    .padding(5)
                    .foregroundStyle(status.tint)
                    .background(.thinMaterial, in: Circle())
                    .padding(6)
                    .accessibilityLabel(status.label)
            }
        }
    }

    private var glowColor: Color {
        item.itemStatus?.tint ?? .clear
    }
}
