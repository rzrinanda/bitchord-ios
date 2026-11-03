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
                
                #if os(iOS)
                YouTubeBridgeView()
                    .frame(width: 24, height: 24)
                    .opacity(0.02)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                #endif
            }
        }
    }
}
