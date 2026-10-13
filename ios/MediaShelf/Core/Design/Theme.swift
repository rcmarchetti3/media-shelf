// Theme.swift
// The MediaShelf design system, ported from frontend/src/index.css.
//
// The web app is a warm, dark "library" look: walnut backgrounds, brass
// accents, parchment text, serif headings, wooden shelf planks. The tokens
// below use the same OKLCH values as the CSS so the two clients stay in
// step; `Color.oklch` converts them to sRGB at runtime.
//
// The web is dark only. iOS follows the system setting, so every surface
// token has a light variant (parchment paper instead of walnut). Wood,
// brass, and the status glows are the same in both modes.
//
// Per the brief, system chrome (nav bars, tab bars, sheets) is left alone.
// These tokens are for content: the shelf, covers, plaques, and backgrounds.

import SwiftUI
import UIKit

enum Theme {

    // MARK: Surfaces

    /// `--background`. Walnut in dark, parchment in light.
    static let background = Color(light: .oklch(0.95, 0.025, 80), dark: .oklch(0.24, 0.02, 55))

    /// `--card`. Rows, tiles, and grouped cells sit on this.
    static let card = Color(light: .oklch(0.99, 0.012, 85), dark: .oklch(0.29, 0.025, 55))

    /// `--muted`. Skeletons, placeholders, empty cover art.
    static let muted = Color(light: .oklch(0.90, 0.02, 80), dark: .oklch(0.32, 0.025, 55))

    /// `--border`.
    static let border = Color(light: .oklch(0.84, 0.03, 75), dark: .oklch(0.37, 0.03, 55))

    // MARK: Text

    /// `--foreground`. Parchment on walnut; walnut on parchment.
    static let foreground = Color(light: .oklch(0.25, 0.03, 55), dark: .oklch(0.92, 0.02, 80))

    /// `--muted-foreground`. Subtitles and secondary labels.
    static let mutedForeground = Color(light: .oklch(0.48, 0.03, 60), dark: .oklch(0.63, 0.03, 70))

    // MARK: Brand

    /// `--brass` / `--primary`. The accent. Slightly darker in light mode for contrast.
    static let brass = Color(light: .oklch(0.60, 0.12, 72), dark: .oklch(0.72, 0.12, 75))
    static let brassDark = Color.oklch(0.58, 0.10, 70)
    /// `--primary-foreground`. Text on top of brass.
    static let onBrass = Color.oklch(0.20, 0.02, 55)
    static let parchment = Color.oklch(0.88, 0.04, 80)
    static let leather = Color.oklch(0.35, 0.06, 45)

    // MARK: Wood

    static let shelfPlank = Color.oklch(0.45, 0.07, 60)
    static let shelfDark = Color.oklch(0.35, 0.05, 55)
    static let shelfLight = Color.oklch(0.52, 0.07, 65)

    /// The `.shelf-row::after` gradient: alternating grain bands across the plank.
    static let plankGradient = LinearGradient(
        stops: [
            .init(color: shelfDark, location: 0.00),
            .init(color: shelfPlank, location: 0.08),
            .init(color: shelfLight, location: 0.18),
            .init(color: shelfPlank, location: 0.28),
            .init(color: shelfDark, location: 0.40),
            .init(color: shelfPlank, location: 0.50),
            .init(color: shelfLight, location: 0.60),
            .init(color: shelfPlank, location: 0.72),
            .init(color: shelfDark, location: 0.82),
            .init(color: shelfPlank, location: 0.92),
            .init(color: shelfLight, location: 1.00),
        ],
        startPoint: .leading, endPoint: .trailing)

    /// The `.stat-plaque` brass gradient.
    static let plaqueGradient = LinearGradient(
        colors: [
            .oklch(0.66, 0.10, 74),
            .oklch(0.73, 0.12, 78),
            .oklch(0.69, 0.11, 72),
            .oklch(0.75, 0.12, 80),
            .oklch(0.71, 0.11, 74),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let plaqueBorder = Color.oklch(0.54, 0.08, 68)

    // MARK: Covers

    /// `.item-cover` background behind art that hasn't loaded or doesn't exist.
    static let coverBackground = Color.oklch(0.28, 0.03, 52)
    /// The initial letter drawn on an empty cover.
    static let coverPlaceholderText = Color.oklch(0.55, 0.05, 60)
    /// Shadow every cover casts to its right, like it's leaning on the next one.
    static let coverShadow = Color.oklch(0.10, 0.02, 50, alpha: 0.55)

    // MARK: Status glows (the `.status-*` rules)

    static let glowCompleted = Color.oklch(0.60, 0.18, 150)
    static let glowInProgress = Color.oklch(0.58, 0.16, 250)
    static let glowWishlist = Color.oklch(0.60, 0.14, 330)
    static let glowDropped = Color.oklch(0.50, 0.12, 25)
    static let glowOwned = Color.oklch(0.55, 0.08, 80)

    // MARK: Type

    /// Headings use the serif design, standing in for Bitter on the web.
    static func heading(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - Color helpers

extension Color {
    /// Builds a color from OKLCH, the space the web stylesheet uses, so
    /// tokens can be copied across verbatim. Standard Ottosson matrices;
    /// out-of-gamut channels are clamped.
    static func oklch(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) -> Color {
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b

        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_

        let r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

        func gamma(_ x: Double) -> Double {
            let x = min(max(x, 0), 1)
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
        return Color(.sRGB, red: gamma(r), green: gamma(g), blue: gamma(bl), opacity: alpha)
    }

    /// A color that resolves differently in light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Texture

/// Faint horizontal grain over the walnut, from the web's `.sidebar-wood`
/// and `.auth-bg` repeating gradients. Static, drawn once per layout.
struct WoodGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var i = 0
            // Barely there: a hint of grain, not ruled paper.
            while y < size.height {
                let alpha = i % 5 == 0 ? 0.05 : 0.025
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                         with: .color(.black.opacity(alpha)))
                y += CGFloat(4 + (i * 7) % 6)
                i += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Small pieces

/// A capsule label: status, type, year. Tinted when given a color.
struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color? = nil

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(tint ?? Theme.mutedForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((tint ?? Theme.border).opacity(tint == nil ? 0.25 : 0.15), in: Capsule())
        .overlay(Capsule().strokeBorder((tint ?? Theme.border).opacity(0.6), lineWidth: 1))
    }
}

// MARK: - View helpers

extension View {
    /// Warm background behind a scroll view, list, or form. Hides the system
    /// grouped background so the walnut (with its grain) shows through.
    func shelfBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Theme.background
                    WoodGrain()
                }
                .ignoresSafeArea()
            }
    }

    /// Card-colored rows for List and Form sections on a shelf background.
    func shelfRow() -> some View {
        listRowBackground(Theme.card)
    }

    /// A free-standing card on the shelf background.
    func shelfCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border.opacity(0.6), lineWidth: 1))
    }
}
