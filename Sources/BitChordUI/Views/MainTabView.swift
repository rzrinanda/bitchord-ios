import SwiftUI

public struct MainTabView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var showingNowPlaying: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Listen Now", systemImage: "play.circle.fill")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "square.stack.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(.red)
            
            // Persistent Floating Mini Player
            if engine.currentTrack != nil {
                MiniPlayerBar {
                    showingNowPlaying = true
                }
                .padding(.bottom, 54) // Above standard tab bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showingNowPlaying) {
            NowPlayingView()
        }
    }
}
