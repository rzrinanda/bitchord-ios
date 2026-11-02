import SwiftUI

public struct BitChordLogoView: View {
    public var size: CGFloat
    public var cornerRadius: CGFloat
    
    public init(size: CGFloat = 40, cornerRadius: CGFloat? = nil) {
        self.size = size
        self.cornerRadius = cornerRadius ?? (size * 0.22)
    }
    
    public var body: some View {
        ZStack {
            // Vibrant BitChord Apple Music gradient tile
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.15, blue: 0.35),
                    Color(red: 0.80, green: 0.05, blue: 0.40),
                    Color(red: 0.45, green: 0.02, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.red.opacity(0.3), radius: size * 0.15, x: 0, y: size * 0.08)
            
            // Stylized BitChord double-stem connected chord glyph
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Left Note Head
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: w * 0.26, height: h * 0.18)
                        .rotationEffect(.degrees(-20))
                        .position(x: w * 0.35, y: h * 0.68)
                    
                    // Right Note Head
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: w * 0.26, height: h * 0.18)
                        .rotationEffect(.degrees(-20))
                        .position(x: w * 0.68, y: h * 0.58)
                    
                    // Stems
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.06, height: h * 0.42)
                        .position(x: w * 0.44, y: h * 0.48)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.06, height: h * 0.32)
                        .position(x: w * 0.77, y: h * 0.43)
                    
                    // Beams
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.39, height: h * 0.08)
                        .position(x: w * 0.605, y: h * 0.28)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.39, height: h * 0.06)
                        .position(x: w * 0.605, y: h * 0.38)
                    
                    // Soundwave bars
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: w * 0.04, height: h * 0.20)
                        .position(x: w * 0.18, y: h * 0.52)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: w * 0.035, height: h * 0.10)
                        .position(x: w * 0.11, y: h * 0.52)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
