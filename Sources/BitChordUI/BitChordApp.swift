import SwiftUI

@main
public struct BitChordApp: App {
    @StateObject private var settings = BitChordSettings.shared
    @StateObject private var engine = AudioPlayerEngine.shared
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
    }
}
