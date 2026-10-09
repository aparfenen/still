import SwiftUI

enum Brand {
    static let lavender = Color(red: 0.69, green: 0.59, blue: 0.86)
}

struct StillHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "flag.fill").foregroundStyle(Brand.lavender)
                .overlay(Image(systemName: "flag").foregroundStyle(Color.primary.opacity(0.45)))
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
