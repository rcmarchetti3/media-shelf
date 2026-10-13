// ShelfPlank.swift
// The wooden shelf a row of covers stands on. Ports `.shelf-row::after`
// (top surface) and `.shelf-row::before` (front edge) from index.css.
//
// Covers should sit with their bottom edge on `topSurfaceHeight`, so the
// plank reads as a surface they rest on rather than a stripe behind them.

import SwiftUI

struct ShelfPlank: View {
    static let topSurfaceHeight: CGFloat = 18
    static let frontEdgeHeight: CGFloat = 6
    static var totalHeight: CGFloat { topSurfaceHeight + frontEdgeHeight }

    var body: some View {
        VStack(spacing: 0) {
            // Top surface: grain gradient with a highlight on the lip and a
            // shadow line where it meets the front edge.
            Rectangle()
                .fill(Theme.plankGradient)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.oklch(0.55, 0.06, 65, alpha: 0.35))
                        .frame(height: 2)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.oklch(0.25, 0.04, 50, alpha: 0.4))
                        .frame(height: 2)
                }
                .frame(height: Self.topSurfaceHeight)

            // Front edge.
            Rectangle()
                .fill(LinearGradient(
                    colors: [.oklch(0.32, 0.04, 55), .oklch(0.27, 0.03, 50)],
                    startPoint: .top, endPoint: .bottom))
                .frame(height: Self.frontEdgeHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .oklch(0.08, 0.02, 50, alpha: 0.6), radius: 5, y: 4)
        .accessibilityHidden(true)
    }
}

#Preview("Plank") {
    ShelfPlank().padding().background(Theme.background)
}
