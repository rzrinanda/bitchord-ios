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
                    .frame(width: 2, height: 2)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                #endif
            }
        }
    }
}
