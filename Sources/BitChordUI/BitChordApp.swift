import SwiftUI

@main
public struct BitChordApp: App {
    @StateObject private var settings = BitChordSettings.shared
    @StateObject private var engine = AudioPlayerEngine.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                #if os(iOS)
                YouTubeBridgeView()
                    .frame(width: 120, height: 120)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                #endif
                
                MainTabView()
                    .environmentObject(settings)
                    .environmentObject(engine)
                    .preferredColorScheme(.dark)
                    .background(Color.black)
            }
        }
    }
}
