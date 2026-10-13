// ShelfItemView.swift
// One cover on the shelf. Replaces frontend/src/components/ShelfItem.tsx.
//
// The cover is a MediaCover (per-type treatment plus status glow) with the
// web's `.item-info` caption on its face: title, status mark and type, and
// stars in brass over a dark gradient. The web only shows that on hover;
// there's no hover on a phone, so it's always on. A favorite heart sits in
// the top corner. The wooden shelf is drawn by ShelfRow, not here.

import SwiftUI

struct ShelfItemView: View {
    let item: CollectionItem

    var body: some View {
        MediaCover(mediaType: item.mediaType, imageURL: item.imageURL,
                   title: item.title, glow: item.itemStatus?.glow) {
            caption
        }
        .overlay(alignment: .topTrailing) {
            if item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.glowWishlist)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .padding(5)
                    .accessibilityLabel("Favorite")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.oklch(0.93, 0.02, 80))
                .shadow(color: .oklch(0.08, 0.01, 50, alpha: 0.8), radius: 2, y: 1)
            HStack(spacing: 3) {
                if let status = item.itemStatus {
                    Image(systemName: status.symbol)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(status.tint)
                        .accessibilityLabel(status.label)
                }
                Text(item.mediaType.singular)
                    .foregroundStyle(Color.oklch(0.72, 0.06, 65))
                if let rating = item.rating, rating > 0 {
                    Text(String(repeating: "★", count: rating))
                        .foregroundStyle(Theme.brass)
                        .accessibilityLabel("\(rating) of 5 stars")
                }
            }
            .font(.system(size: 9))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .padding(.top, 26)
        .background(LinearGradient(
            colors: [.clear, .oklch(0.10, 0.02, 50, alpha: 0.93)],
            startPoint: .top, endPoint: .bottom))
    }
}

/// Lifts the cover off the shelf while it's pressed, the way the web's
/// `.shelf-item:hover` raises and brightens it.
struct CoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? -10 : 0)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("Items") {
    HStack(alignment: .bottom, spacing: 12) {
        ForEach(PreviewData.items.prefix(3)) { ShelfItemView(item: $0) }
    }
    .padding()
    .background(Theme.background)
}
#endif
