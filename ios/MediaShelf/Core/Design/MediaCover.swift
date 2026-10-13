// MediaCover.swift
// Cover art drawn as the physical object it represents. Ports the
// `.shelf-item.type-*` rules from index.css:
//
//   vinyl       square sleeve, record peeking out top-right
//   book        tall, dark spine on the left, page edges on the right
//   movie/show/documentary
//               DVD case: narrow spine, plastic sheen across the top
//   audiobook   CD jewel case: thin blue spine, disc peeking bottom-right
//
// A status glow (`.status-*`) is an inset 2pt ring plus a soft outer glow.
// An optional caption is laid over the bottom of the art, inside the clip,
// so the cover can stand directly on the shelf with its label on its face.
// Used at thumbnail size on the shelf and at full size on the detail screen.

import SwiftUI

struct MediaCover<Caption: View>: View {
    let mediaType: MediaType
    let imageURL: URL?
    let title: String
    var glow: Color?
    var cornerRadius: CGFloat
    private let caption: Caption

    init(mediaType: MediaType, imageURL: URL?, title: String,
         glow: Color? = nil, cornerRadius: CGFloat = 2,
         @ViewBuilder caption: () -> Caption) {
        self.mediaType = mediaType
        self.imageURL = imageURL
        self.title = title
        self.glow = glow
        self.cornerRadius = cornerRadius
        self.caption = caption()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottom) {
                art(width: w, height: h)
                typeOverlay(width: w, height: h)
                caption
            }
            .frame(width: w, height: h)
            .clipShape(shape)
            .overlay {
                if let glow {
                    shape.strokeBorder(glow, lineWidth: 2)
                }
            }
            .background(alignment: .topTrailing) {
                if mediaType == .vinyl { vinylRecord(size: w) }
            }
            .background(alignment: .trailing) {
                if mediaType == .book { bookPages(width: w, height: h) }
            }
        }
        .aspectRatio(mediaType.coverAspect, contentMode: .fit)
        // Shadow to the right, like it's leaning on its neighbor.
        .shadow(color: Theme.coverShadow, radius: 5, x: 3)
        // The status glow. Deliberately stronger than the web (OLED can take it).
        .shadow(color: glow?.opacity(0.55) ?? .clear, radius: 8)
        .accessibilityLabel(title)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    // MARK: Art

    private func art(width w: CGFloat, height h: CGFloat) -> some View {
        RemoteImage(url: imageURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                placeholder(width: w)
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }

    /// The web shows the first letter of the title in the heading face,
    /// sized to the cover rather than filling it.
    private func placeholder(width w: CGFloat) -> some View {
        ZStack {
            Theme.coverBackground
            Text(title.prefix(1).uppercased())
                .font(.system(size: w * 0.34, design: .serif).weight(.bold))
                .foregroundStyle(Theme.coverPlaceholderText)
        }
    }

    // MARK: Per-type treatments (clipped to the cover)

    @ViewBuilder
    private func typeOverlay(width w: CGFloat, height h: CGFloat) -> some View {
        switch mediaType {
        case .vinyl:
            EmptyView()

        case .book:
            // Spine.
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.oklch(0.20, 0.03, 50), .oklch(0.26, 0.04, 52), .oklch(0.22, 0.03, 50)],
                    startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.124)
                Spacer(minLength: 0)
            }

        case .movie, .show, .documentary:
            // Case spine and plastic sheen.
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.oklch(0.95, 0.01, 80, alpha: 0.07), .clear],
                    startPoint: .top, endPoint: .bottom)
                .frame(height: h * 0.35)
                LinearGradient(
                    colors: [.oklch(0.16, 0.01, 50), .oklch(0.23, 0.02, 52), .oklch(0.18, 0.01, 50)],
                    startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.098)
            }
            .frame(width: w, height: h, alignment: .topLeading)

        case .audiobook:
            // Jewel case spine and a CD peeking out bottom-right.
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.oklch(0.16, 0.01, 220), .oklch(0.28, 0.02, 220), .oklch(0.18, 0.01, 220)],
                    startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.073)

                compactDisc(size: w * 0.673)
                    .offset(x: w * (1 - 0.673 + 0.182), y: h * (1 - 0.673 + 0.182))
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    // MARK: Pieces that stick out past the cover

    /// The record, mostly hidden behind the sleeve, up and to the right.
    /// Peeks out a little less than on the web so the last column doesn't
    /// run off the edge of a narrow display.
    private func vinylRecord(size w: CGFloat) -> some View {
        let d = w * 0.9
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .oklch(0.22, 0.01, 50), location: 0.00),
                        .init(color: .oklch(0.22, 0.01, 50), location: 0.12),
                        .init(color: .oklch(0.16, 0.01, 50), location: 0.125),
                        .init(color: .oklch(0.20, 0.015, 50), location: 0.13),
                        .init(color: .oklch(0.20, 0.015, 50), location: 0.42),
                        .init(color: .oklch(0.15, 0.01, 50), location: 0.425),
                        .init(color: .oklch(0.19, 0.015, 50), location: 0.43),
                        .init(color: .oklch(0.19, 0.015, 50), location: 0.72),
                        .init(color: .oklch(0.14, 0.01, 50), location: 0.725),
                        .init(color: .oklch(0.17, 0.01, 50), location: 0.73),
                        .init(color: .oklch(0.17, 0.01, 50), location: 1.00),
                    ],
                    center: .center, startRadius: 0, endRadius: d / 2))
                .overlay {
                    if let glow { Circle().strokeBorder(glow, lineWidth: 2) }
                }
                .shadow(color: .oklch(0.10, 0.01, 50, alpha: 0.5), radius: 4, x: 2, y: 3)
            // Label.
            Circle()
                .fill(Color.oklch(0.52, 0.06, 65))
                .frame(width: d * 0.103)
        }
        .frame(width: d, height: d)
        .offset(x: w * 0.05, y: -w * 0.08)
    }

    /// Page block on the right edge of a book: fine alternating lines.
    private func bookPages(width w: CGFloat, height h: CGFloat) -> some View {
        let pageWidth = w * 0.057
        return Canvas { ctx, size in
            var y: CGFloat = 0
            var light = true
            while y < size.height {
                let color: Color = light ? .oklch(0.84, 0.02, 80) : .oklch(0.76, 0.03, 75)
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(color))
                y += 1
                light.toggle()
            }
        }
        .frame(width: pageWidth, height: h * (1 - 0.027))
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 1, topTrailingRadius: 1))
        .offset(x: pageWidth * 0.84)
    }

    /// Iridescent disc for the jewel case.
    private func compactDisc(size d: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: .oklch(0.28, 0.01, 50), location: 0.00),
                    .init(color: .oklch(0.28, 0.01, 50), location: 0.10),
                    .init(color: .oklch(0.58, 0.04, 200, alpha: 0.35), location: 0.10),
                    .init(color: .oklch(0.68, 0.05, 280, alpha: 0.30), location: 0.40),
                    .init(color: .oklch(0.62, 0.04, 100, alpha: 0.25), location: 0.60),
                    .init(color: .oklch(0.50, 0.03, 50), location: 1.00),
                ],
                center: .center, startRadius: 0, endRadius: d / 2))
            .frame(width: d, height: d)
    }
}

extension MediaCover where Caption == EmptyView {
    /// A cover with no caption.
    init(mediaType: MediaType, imageURL: URL?, title: String,
         glow: Color? = nil, cornerRadius: CGFloat = 2) {
        self.init(mediaType: mediaType, imageURL: imageURL, title: title,
                  glow: glow, cornerRadius: cornerRadius) { EmptyView() }
    }
}

#Preview("Types") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
            ForEach(MediaType.allCases) { type in
                MediaCover(mediaType: type, imageURL: nil, title: type.label, glow: Theme.glowCompleted)
            }
        }
        .padding(24)
    }
    .background(Theme.background)
}
