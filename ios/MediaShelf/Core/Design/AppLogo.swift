// AppLogo.swift
// The MediaShelf mark from frontend/public/favicon.svg: two books and a
// record on a shelf. Drawn in a 32x32 space and scaled to whatever frame
// it's given, in the current tint (brass by default).

import SwiftUI

struct AppLogo: View {
    var color: Color = Theme.brass

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 32
            ctx.translateBy(x: (size.width - 32 * s) / 2, y: (size.height - 32 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
            }

            // Shelf base, left book, right book.
            ctx.fill(rect(3, 24, 26, 2.5, r: 1), with: .color(color))
            ctx.fill(rect(6, 8, 4, 16, r: 1), with: .color(color))
            ctx.fill(rect(22, 10, 4, 14, r: 1), with: .color(color))

            // Record.
            ctx.stroke(Path(ellipseIn: CGRect(x: 10.5, y: 10.5, width: 11, height: 11)),
                       with: .color(color), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: 14.5, y: 14.5, width: 3, height: 3)), with: .color(color))

            // Film strip accent on the right book.
            ctx.fill(rect(23, 11, 2, 1.5, r: 0.3), with: .color(.white.opacity(0.5)))
            ctx.fill(rect(23, 13.5, 2, 1.5, r: 0.3), with: .color(.white.opacity(0.5)))
        }
        .accessibilityLabel("MediaShelf")
    }
}

#Preview {
    AppLogo().frame(width: 96, height: 96).padding().background(Theme.background)
}
