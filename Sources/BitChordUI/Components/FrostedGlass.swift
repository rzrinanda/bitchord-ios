import SwiftUI
import BitChordCore

public struct FrostedGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var opacity: Double = 0.8
    
    public init(cornerRadius: CGFloat = 16, opacity: Double = 0.8) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

public extension View {
    func frostedGlass(cornerRadius: CGFloat = 16, opacity: Double = 0.8) -> some View {
        self.modifier(FrostedGlassModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}
