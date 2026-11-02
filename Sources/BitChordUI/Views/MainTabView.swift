import SwiftUI

public enum BitChordTab: Int, CaseIterable, Identifiable {
    case home = 0
    case explore = 1
    case library = 2
    case search = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .library: return "Library"
        case .search: return "Search"
        }
    }
    
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .explore: return "square.grid.2x2.fill"
        case .library: return "square.stack.fill"
        case .search: return "magnifyingglass"
        }
    }
}

public struct MainTabView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var selectedTab: BitChordTab = .home
    @State private var showingNowPlaying: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Screens
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .explore:
                    ExploreView()
                case .library:
                    LibraryView()
                case .search:
                    SearchView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Overlays: Floating Mini Player + Floating Capsule Tab Bar
            VStack(spacing: 8) {
                // Floating Mini Player (Matching Car HU Photo 1, 2, 3, 4)
                if engine.currentTrack != nil {
                    MiniPlayerBar {
                        showingNowPlaying = true
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Floating Capsule Navigation Bar (Matching Car HU Bottom Bar)
                HStack(spacing: 0) {
                    ForEach(BitChordTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(tab.title)
                                    .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                            }
                            .foregroundColor(selectedTab == tab ? .white : .secondary.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                    ? Color.white.opacity(0.18)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(UIColor.systemBackground).opacity(0.88))
                        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
                )
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showingNowPlaying) {
            NowPlayingView()
        }
    }
}
