import SwiftUI

@main
public struct BitChordApp: App {
    @StateObject private var settings = BitChordSettings.shared
    @StateObject private var engine = AudioPlayerEngine.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                MainTabView()
                    .environmentObject(settings)
                    .environmentObject(engine)
                    .preferredColorScheme(.dark)
                    .background(Color.black)
                
                #if os(iOS)
                YouTubeBridgeView()
                    .frame(width: 32, height: 32)
                    .opacity(1.0)
                    .offset(x: -9999, y: -9999)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                #endif
            }
        }
    }
}
