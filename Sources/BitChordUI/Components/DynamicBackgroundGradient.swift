import SwiftUI

public struct DynamicBackgroundGradient: View {
    public var accentColor: Color
    @State private var animateGradient: Bool = false
    
    public init(accentColor: Color = Color.red.opacity(0.6)) {
        self.accentColor = accentColor
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Fluid ambient gradient blobs
            Circle()
                .fill(accentColor.opacity(0.45))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: animateGradient ? -80 : 80, y: animateGradient ? -120 : 60)
            
            Circle()
                .fill(Color.purple.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: animateGradient ? 100 : -70, y: animateGradient ? 140 : -80)
            
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}
