import SwiftUI

@main
public struct BitChordApp: App {
    @StateObject private var settings = BitChordSettings.shared
    @StateObject private var engine = AudioPlayerEngine.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ZStack {
                #if os(iOS)
                YouTubeBridgeView()
                    .frame(width: 100, height: 100)
                    .opacity(0.04)
                    .allowsHitTesting(false)
                    .zIndex(-999)
                #endif
                
                MainTabView()
                    .environmentObject(settings)
                    .environmentObject(engine)
                    .preferredColorScheme(.dark)
                    .zIndex(1)
            }
        }
    }
}
