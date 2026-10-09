import SwiftUI

enum Brand {
    static let lavender = Color(red: 0.69, green: 0.59, blue: 0.86)
}

struct StillHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            BookmarkMark().fill(Brand.lavender).frame(width: 12, height: 16)
                .accessibilityHidden(true)
            Text("still").font(.system(size: 17, weight: .medium, design: .rounded))
        }.accessibilityElement(children: .combine).accessibilityLabel("Still")
    }
}

enum ReaderDefaults {
    static let font = "system"
    static let size = 17.0
    static let spacing = 7.0
    static let inset = 28.0
}

/// The user's reference: a straight ribbon with a triangular cutout.
struct BookmarkMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2 / 3))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
