import SwiftUI

public struct ExploreView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @State private var showingAccountMenu: Bool = false
    @State private var selectedTrackForMenu: Track? = nil
    
    // Top 3 YT Music Navigation Cards
    private let topCategoryCards: [(title: String, icon: String, query: String, color: Color)] = [
        ("New releases", "sparkles.rectangle.stack.fill", "New Releases Official Songs", Color(red: 0.90, green: 0.25, blue: 0.35)),
        ("Charts", "chart.line.uptrend.xyaxis", "Top 100 Songs Chart", Color(red: 0.20, green: 0.55, blue: 0.95)),
        ("Moods & genres", "face.smiling.inverse", "Best Moods & Genres Hits", Color(red: 0.65, green: 0.30, blue: 0.90))
    ]
    
    // New Albums & Singles
    private let newAlbumsAndSingles: [Track] = [
        Track(
            id: "kPa7bsKwL-c",
            title: "Die With A Smile",
            artist: "Lady Gaga & Bruno Mars",
            album: "Single • 2026",
            duration: 251,
            artworkURL: URL(string: "https://i.ytimg.com/vi/kPa7bsKwL-c/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "V9PVRfjEBTI",
            title: "BIRDS OF A FEATHER",
            artist: "Billie Eilish",
            album: "Album • HIT ME HARD AND SOFT",
            duration: 210,
            artworkURL: URL(string: "https://i.ytimg.com/vi/V9PVRfjEBTI/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "eVli-tstM5E",
            title: "Espresso",
            artist: "Sabrina Carpenter",
            album: "Single • Short n' Sweet",
            duration: 175,
            artworkURL: URL(string: "https://i.ytimg.com/vi/eVli-tstM5E/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "IqxdiPd_q40",
            title: "Mimpi Yang Sempurna",
            artist: "NOAH",
            album: "Album • Taman Langit",
            duration: 218,
            artworkURL: URL(string: "https://i.ytimg.com/vi/IqxdiPd_q40/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "utgn0LCDirk",
            title: "Kangen",
            artist: "Dewa 19",
            album: "Album • 19",
            duration: 312,
            artworkURL: URL(string: "https://i.ytimg.com/vi/utgn0LCDirk/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    // Curated Charts (YouTube Music Charts)
    private let charts: [(title: String, subtitle: String, image: String, color: Color)] = [
        ("Top 100 Indonesia", "Daily music charts", "chart.bar.fill", Color(red: 0.90, green: 0.18, blue: 0.28)),
        ("Top 100 Global", "Worldwide hits", "globe.americas.fill", Color(red: 0.15, green: 0.50, blue: 0.92)),
        ("Trending 20", "Fastest rising tracks", "flame.fill", Color(red: 0.95, green: 0.45, blue: 0.12)),
        ("Indonesian Legends", "90s & 2000s rock/pop", "guitars.fill", Color(red: 0.55, green: 0.22, blue: 0.85))
    ]
    
    // Moods & Genres (YouTube Music colored left-border strips)
    private let moodsAndGenres: [(name: String, stripeColor: Color)] = [
        ("Chill", .cyan),
        ("Commute", .orange),
        ("Energy Boosters", .yellow),
        ("Feel Good", .green),
        ("Focus", .indigo),
        ("Workout", .red),
        ("Romance", .pink),
        ("Party", .purple),
        ("Indonesian Pop", .mint),
        ("Rock & Alternative", .red),
        ("R&B & Soul", .blue),
        ("Jazz & Acoustic", .brown),
        ("Indie & Senja", .teal),
        ("Sleep", .purple)
    ]
    
    // Trending Songs (Ranked 1..8 with YT Music numbering)
    private let trendingSongs: [Track] = [
        Track(
            id: "IqxdiPd_q40",
            title: "Mimpi Yang Sempurna",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 218,
            artworkURL: URL(string: "https://i.ytimg.com/vi/IqxdiPd_q40/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "utgn0LCDirk",
            title: "Kangen",
            artist: "Dewa 19",
            album: "19",
            duration: 312,
            artworkURL: URL(string: "https://i.ytimg.com/vi/utgn0LCDirk/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "b0ZBBjViV8Y",
            title: "Separuh Aku",
            artist: "NOAH",
            album: "Seperti Seharusnya",
            duration: 268,
            artworkURL: URL(string: "https://i.ytimg.com/vi/b0ZBBjViV8Y/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "N43bVhtyVt4",
            title: "Roman Picisan",
            artist: "Dewa 19",
            album: "Bintang Lima",
            duration: 243,
            artworkURL: URL(string: "https://i.ytimg.com/vi/N43bVhtyVt4/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "CNbmVEEW-mA",
            title: "Yang Terdalam",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 198,
            artworkURL: URL(string: "https://i.ytimg.com/vi/CNbmVEEW-mA/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "kPa7bsKwL-c",
            title: "Die With A Smile",
            artist: "Lady Gaga & Bruno Mars",
            album: "Single",
            duration: 251,
            artworkURL: URL(string: "https://i.ytimg.com/vi/kPa7bsKwL-c/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "34Na4j8AVgA",
            title: "Starboy",
            artist: "The Weeknd ft. Daft Punk",
            album: "Starboy",
            duration: 230,
            artworkURL: URL(string: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "5NV6Rdv1a3I",
            title: "Get Lucky",
            artist: "Daft Punk ft. Pharrell Williams",
            album: "Random Access Memories",
            duration: 248,
            artworkURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: - 1. Top 3 YouTube Music Category Cards (New releases, Charts, Moods & genres)
                    topNavigationCardsSection
                    
                    // MARK: - 2. New Albums & Singles
                    newAlbumsSection
                    
                    // MARK: - 3. Trending (Ranked 4-row horizontal paging list like YT Music)
                    trendingRankedSection
                    
                    // MARK: - 4. Moods & Genres Grid (Colored left accent bar like YT Music)
                    moodsAndGenresSection
                    
                    // MARK: - 5. Charts & Tangga Lagu
                    chartsSection
                }
                .padding(.top, 10)
                .padding(.bottom, engine.currentTrack != nil ? 140 : 70)
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAccountMenu = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.85))
                                .frame(width: 32, height: 32)
                            Text(AccountManager.shared.activeAccount.avatarLetter)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
            .sheet(item: $selectedTrackForMenu) { track in
                TrackContextMenuSheet(track: track)
            }
        }
    }
    
    // MARK: - 1. Top 3 YT Music Category Cards (Opens Category Playlists Browser)
    private var topNavigationCardsSection: some View {
        HStack(spacing: 10) {
            ForEach(topCategoryCards, id: \.title) { card in
                NavigationLink {
                    CategoryPlaylistsBrowserView(categoryTitle: card.title)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: card.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(card.color)
                            Spacer()
                        }
                        
                        Text(card.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 2. New Albums & Singles (Opens Album / Single Tracklist)
    private var newAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("New albums & singles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink {
                    CategoryPlaylistsBrowserView(categoryTitle: "New releases")
                } label: {
                    Text("More")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(newAlbumsAndSingles) { track in
                        NavigationLink {
                            PlaylistOrAlbumDetailView(
                                item: SearchResultItem(
                                    id: "album_\(track.id)",
                                    title: track.title,
                                    subtitle: "\(track.album) • \(track.artist)",
                                    type: .album,
                                    artist: track.artist,
                                    album: track.album,
                                    artworkURL: track.artworkURL
                                )
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    TrackArtworkView(track: track, size: 155, cornerRadius: 12)
                                    
                                    Circle()
                                        .fill(Color.black.opacity(0.45))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "play.circle")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.9))
                                        )
                                        .padding(8)
                                }
                                
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text("\(track.album) • \(track.artist)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 155)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 3. Trending Ranked Songs (YouTube Music 4-row numbered shelf)
    private var trendingRankedSection: some View {
        let columns = stride(from: 0, to: trendingSongs.count, by: 4).map {
            Array(trendingSongs.enumerated())[($0)..<min($0 + 4, trendingSongs.count)]
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trending")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    engine.setQueue(trendingSongs, startIndex: 0)
                    if let first = trendingSongs.first {
                        library.recordPlayback(track: first)
                    }
                } label: {
                    Text("Play all")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(0..<columns.count, id: \.self) { colIdx in
                        VStack(spacing: 10) {
                            ForEach(Array(columns[colIdx]), id: \.element.id) { item in
                                let rank = item.offset + 1
                                let track = item.element
                                
                                HStack(spacing: 10) {
                                    Button {
                                        engine.setQueue(trendingSongs, startIndex: item.offset)
                                        library.recordPlayback(track: track)
                                    } label: {
                                        HStack(spacing: 10) {
                                            TrackArtworkView(track: track, size: 48, cornerRadius: 8)
                                            
                                            // Rank Number + Green Trend Dot
                                            VStack(spacing: 2) {
                                                Text("\(rank)")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.primary)
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 5, height: 5)
                                            }
                                            .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(track.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(engine.currentTrack?.id == track.id ? .red : .primary)
                                                    .lineLimit(1)
                                                Text("\(track.artist) • \(track.album)")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer(minLength: 4)
                                            
                                            if engine.currentTrack?.id == track.id {
                                                Image(systemName: "waveform")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        selectedTrackForMenu = track
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, height: 30)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(width: 305)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 4. Moods & Genres Section (Opens Category Playlists Browser)
    private var moodsAndGenresSection: some View {
        let rows = stride(from: 0, to: moodsAndGenres.count, by: 3).map {
            Array(moodsAndGenres[$0..<min($0 + 3, moodsAndGenres.count)])
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Moods & genres")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink {
                    CategoryPlaylistsBrowserView(categoryTitle: "Moods & genres")
                } label: {
                    Text("More")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(0..<rows.count, id: \.self) { colIdx in
                        VStack(spacing: 10) {
                            ForEach(rows[colIdx], id: \.name) { item in
                                NavigationLink {
                                    CategoryPlaylistsBrowserView(categoryTitle: item.name)
                                } label: {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(item.stripeColor)
                                            .frame(width: 6)
                                        
                                        HStack {
                                            Text(item.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                    .frame(width: 175, height: 48)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 5. Charts Section (Opens Chart Playlist Tracklist)
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Charts")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                NavigationLink {
                    CategoryPlaylistsBrowserView(categoryTitle: "Charts")
                } label: {
                    Text("More")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(charts, id: \.title) { chart in
                        NavigationLink {
                            PlaylistOrAlbumDetailView(
                                item: SearchResultItem(
                                    id: "chart_\(chart.title)",
                                    title: chart.title,
                                    subtitle: "Chart Playlist • \(chart.subtitle)",
                                    type: .playlist,
                                    artist: "YouTube Music"
                                ),
                                customGradient: [chart.color, chart.color.opacity(0.45)]
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(chart.color.gradient)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: chart.image)
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text("TOP 100")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .frame(width: 145, height: 145)
                                
                                Text(chart.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(chart.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 145)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
