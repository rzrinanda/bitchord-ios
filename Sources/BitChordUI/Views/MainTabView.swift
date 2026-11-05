import SwiftUI
#if os(iOS)
import UIKit
#endif

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
        case .explore: return "safari.fill"
        case .library: return "square.stack.fill"
        case .search: return "magnifyingglass"
        }
    }
}

public struct MainTabView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var selectedTab: BitChordTab = .home
    @State private var showingNowPlaying: Bool = false
    @State private var isKeyboardVisible: Bool = false
    
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
            
            // Bottom Overlays: Floating Mini Player + Floating Capsule Tab Bar (Hidden when keyboard is active)
            if !isKeyboardVisible {
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
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.96))
                            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 14)
                .background(
                    ZStack {
                        Color(red: 0.05, green: 0.05, blue: 0.07)
                            .ignoresSafeArea(edges: .bottom)
                        
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.0), location: 0.0),
                                .init(color: Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.85), location: 0.35),
                                .init(color: Color(red: 0.05, green: 0.05, blue: 0.07), location: 0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 36)
                        .offset(y: -18)
                    }
                    .allowsHitTesting(false)
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.22)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.22)) {
                isKeyboardVisible = false
            }
        }
        #endif
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}
