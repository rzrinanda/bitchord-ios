import SwiftUI

public struct ExploreView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @State private var showingAccountMenu: Bool = false
    @State private var selectedTrackForMenu: Track? = nil
    
    @State private var liveNewAlbums: [SearchResultItem] = []
    @State private var liveTrendingSongs: [Track] = []
    @State private var liveChartPlaylists: [String: SearchResultItem] = [:]
    @State private var liveArtists: [SearchResultItem] = []
    @State private var isLoadingLive: Bool = true
    
    // Top 3 YT Music Navigation Cards
    private let topCategoryCards: [(title: String, icon: String, query: String, color: Color)] = [
        ("New releases", "sparkles.rectangle.stack.fill", "New Releases Official Songs", Color(red: 0.90, green: 0.25, blue: 0.35)),
        ("Charts", "chart.line.uptrend.xyaxis", "Top 100 Songs Chart", Color(red: 0.20, green: 0.55, blue: 0.95)),
        ("Moods & genres", "face.smiling.inverse", "Best Moods & Genres Hits", Color(red: 0.65, green: 0.30, blue: 0.90))
    ]
    
    // Curated Fallback New Albums & Singles
    private let fallbackNewAlbums: [SearchResultItem] = [
        SearchResultItem(
            id: "album_die_with_a_smile",
            title: "Die With A Smile",
            subtitle: "Single • Lady Gaga & Bruno Mars",
            type: .album,
            artist: "Lady Gaga & Bruno Mars",
            album: "Die With A Smile",
            artworkURL: URL(string: "https://i.ytimg.com/vi/kPa7bsKwL-c/hqdefault.jpg"),
            videoId: "kPa7bsKwL-c",
            duration: 251
        ),
        SearchResultItem(
            id: "album_hit_me_hard",
            title: "HIT ME HARD AND SOFT",
            subtitle: "Album • Billie Eilish",
            type: .album,
            artist: "Billie Eilish",
            album: "HIT ME HARD AND SOFT",
            artworkURL: URL(string: "https://i.ytimg.com/vi/V9PVRfjEBTI/hqdefault.jpg"),
            videoId: "V9PVRfjEBTI",
            duration: 210
        ),
        SearchResultItem(
            id: "album_short_n_sweet",
            title: "Short n' Sweet",
            subtitle: "Album • Sabrina Carpenter",
            type: .album,
            artist: "Sabrina Carpenter",
            album: "Short n' Sweet",
            artworkURL: URL(string: "https://i.ytimg.com/vi/eVli-tstM5E/hqdefault.jpg"),
            videoId: "eVli-tstM5E",
            duration: 175
        ),
        SearchResultItem(
            id: "album_taman_langit",
            title: "Taman Langit",
            subtitle: "Album • NOAH",
            type: .album,
            artist: "NOAH",
            album: "Taman Langit",
            artworkURL: URL(string: "https://i.ytimg.com/vi/IqxdiPd_q40/hqdefault.jpg"),
            videoId: "IqxdiPd_q40",
            duration: 218
        ),
        SearchResultItem(
            id: "album_dewa_19",
            title: "Bintang Lima",
            subtitle: "Album • Dewa 19",
            type: .album,
            artist: "Dewa 19",
            album: "Bintang Lima",
            artworkURL: URL(string: "https://i.ytimg.com/vi/utgn0LCDirk/hqdefault.jpg"),
            videoId: "utgn0LCDirk",
            duration: 312
        ),
        SearchResultItem(
            id: "album_sialan",
            title: "Sialan",
            subtitle: "Single • Mahalini & Adrian Khalif",
            type: .album,
            artist: "Mahalini",
            album: "Sialan",
            artworkURL: URL(string: "https://i.ytimg.com/vi/8Y4e3fX-b-k/hqdefault.jpg"),
            videoId: "8Y4e3fX-b-k",
            duration: 235
        ),
        SearchResultItem(
            id: "album_untungnya",
            title: "Untungnya, Hidup Harus Tetap Berjalan",
            subtitle: "Album • Bernadya",
            type: .album,
            artist: "Bernadya",
            album: "Untungnya, Hidup Harus Tetap Berjalan",
            artworkURL: URL(string: "https://i.ytimg.com/vi/Gz30Ym8hG7s/hqdefault.jpg"),
            videoId: "Gz30Ym8hG7s",
            duration: 220
        ),
        SearchResultItem(
            id: "album_moon_music",
            title: "Moon Music",
            subtitle: "Album • Coldplay",
            type: .album,
            artist: "Coldplay",
            album: "Moon Music",
            artworkURL: URL(string: "https://i.ytimg.com/vi/31tiWTjL4aI/hqdefault.jpg"),
            videoId: "31tiWTjL4aI",
            duration: 245
        ),
        SearchResultItem(
            id: "album_after_hours",
            title: "After Hours",
            subtitle: "Album • The Weeknd",
            type: .album,
            artist: "The Weeknd",
            album: "After Hours",
            artworkURL: URL(string: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"),
            videoId: "4NRXx6U8ABQ",
            duration: 200
        ),
        SearchResultItem(
            id: "album_monokrom",
            title: "Monokrom",
            subtitle: "Album • Tulus",
            type: .album,
            artist: "Tulus",
            album: "Monokrom",
            artworkURL: URL(string: "https://i.ytimg.com/vi/aL3p-uV5bLg/hqdefault.jpg"),
            videoId: "aL3p-uV5bLg",
            duration: 215
        )
    ]
    
    // Curated Trending Songs Fallback (16 Tracks)
    private let fallbackTrending: [Track] = [
        Track(id: "IqxdiPd_q40", title: "Mimpi Yang Sempurna", artist: "NOAH", album: "Taman Langit", duration: 218, artworkURL: URL(string: "https://i.ytimg.com/vi/IqxdiPd_q40/hqdefault.jpg"), source: .youtube),
        Track(id: "utgn0LCDirk", title: "Kangen", artist: "Dewa 19", album: "19", duration: 312, artworkURL: URL(string: "https://i.ytimg.com/vi/utgn0LCDirk/hqdefault.jpg"), source: .youtube),
        Track(id: "b0ZBBjViV8Y", title: "Separuh Aku", artist: "NOAH", album: "Seperti Seharusnya", duration: 268, artworkURL: URL(string: "https://i.ytimg.com/vi/b0ZBBjViV8Y/hqdefault.jpg"), source: .youtube),
        Track(id: "N43bVhtyVt4", title: "Roman Picisan", artist: "Dewa 19", album: "Bintang Lima", duration: 243, artworkURL: URL(string: "https://i.ytimg.com/vi/N43bVhtyVt4/hqdefault.jpg"), source: .youtube),
        Track(id: "CNbmVEEW-mA", title: "Yang Terdalam", artist: "NOAH", album: "Taman Langit", duration: 198, artworkURL: URL(string: "https://i.ytimg.com/vi/CNbmVEEW-mA/hqdefault.jpg"), source: .youtube),
        Track(id: "kPa7bsKwL-c", title: "Die With A Smile", artist: "Lady Gaga & Bruno Mars", album: "Single", duration: 251, artworkURL: URL(string: "https://i.ytimg.com/vi/kPa7bsKwL-c/hqdefault.jpg"), source: .youtube),
        Track(id: "V9PVRfjEBTI", title: "BIRDS OF A FEATHER", artist: "Billie Eilish", album: "HIT ME HARD AND SOFT", duration: 210, artworkURL: URL(string: "https://i.ytimg.com/vi/V9PVRfjEBTI/hqdefault.jpg"), source: .youtube),
        Track(id: "eVli-tstM5E", title: "Espresso", artist: "Sabrina Carpenter", album: "Short n' Sweet", duration: 175, artworkURL: URL(string: "https://i.ytimg.com/vi/eVli-tstM5E/hqdefault.jpg"), source: .youtube),
        Track(id: "34Na4j8AVgA", title: "Starboy", artist: "The Weeknd ft. Daft Punk", album: "Starboy", duration: 230, artworkURL: URL(string: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"), source: .youtube),
        Track(id: "5NV6Rdv1a3I", title: "Get Lucky", artist: "Daft Punk ft. Pharrell", album: "Random Access Memories", duration: 248, artworkURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"), source: .youtube),
        Track(id: "Gz30Ym8hG7s", title: "Satu Bulan", artist: "Bernadya", album: "Untungnya, Hidup Harus Tetap Berjalan", duration: 204, artworkURL: URL(string: "https://i.ytimg.com/vi/Gz30Ym8hG7s/hqdefault.jpg"), source: .youtube),
        Track(id: "aL3p-uV5bLg", title: "Hati-Hati di Jalan", artist: "Tulus", album: "Manusia", duration: 242, artworkURL: URL(string: "https://i.ytimg.com/vi/aL3p-uV5bLg/hqdefault.jpg"), source: .youtube),
        Track(id: "4NRXx6U8ABQ", title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200, artworkURL: URL(string: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"), source: .youtube),
        Track(id: "31tiWTjL4aI", title: "Yellow", artist: "Coldplay", album: "Parachutes", duration: 269, artworkURL: URL(string: "https://i.ytimg.com/vi/31tiWTjL4aI/hqdefault.jpg"), source: .youtube),
        Track(id: "8Y4e3fX-b-k", title: "Sial", artist: "Mahalini", album: "Fábulas", duration: 243, artworkURL: URL(string: "https://i.ytimg.com/vi/8Y4e3fX-b-k/hqdefault.jpg"), source: .youtube),
        Track(id: "fJ9rUzIMcZQ", title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 354, artworkURL: URL(string: "https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg"), source: .youtube)
    ]
    
    // Daily Top Charts — each resolves LIVE to the real YouTube Music chart playlist via `query`
    private let dailyTopCharts: [(title: String, subtitle: String, image: String, color: Color, query: String)] = [
        ("Daily Top 100 Indonesia", "Top daily national chart", "chart.bar.fill", Color(red: 0.90, green: 0.18, blue: 0.28), "Top 100 Songs Indonesia"),
        ("Daily Top 100 Global", "Worldwide daily hits", "globe.americas.fill", Color(red: 0.15, green: 0.50, blue: 0.92), "Top 100 Songs Global"),
        ("Daily Top Music Videos Indonesia", "Most viewed music videos today", "play.rectangle.fill", Color(red: 0.85, green: 0.25, blue: 0.45), "Top 100 Music Videos Indonesia"),
        ("Daily Top Music Videos Global", "Most viewed worldwide", "play.tv.fill", Color(red: 0.35, green: 0.30, blue: 0.85), "Top 100 Music Videos Global"),
        ("Trending Indonesia", "Fastest rising tracks today", "flame.fill", Color(red: 0.95, green: 0.45, blue: 0.12), "Trending 20 Indonesia"),
        ("Trending Global", "Rising worldwide", "chart.line.uptrend.xyaxis", Color(red: 0.20, green: 0.75, blue: 0.55), "Trending 20 Global"),
        ("Top 100 USA", "United States daily chart", "star.fill", Color(red: 0.55, green: 0.22, blue: 0.85), "Top 100 Songs United States"),
        ("Top 100 South Korea", "K-chart daily", "sparkles", Color(red: 0.90, green: 0.35, blue: 0.65), "Top 100 Songs South Korea")
    ]
    
    // Seed names used only if the live artist chart cannot be fetched (artwork still resolved live)
    private let fallbackArtistNames: [String] = [
        "NOAH", "Dewa 19", "Sheila On 7", "Tulus", "Mahalini", "Bernadya",
        "Bruno Mars", "Taylor Swift", "The Weeknd", "Billie Eilish", "Coldplay", "Lady Gaga"
    ]
    
    // Expanded Moods & Genres (24 choices matching YT Music colored left-border strips)
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
        ("Dangdut Koplo", .yellow),
        ("Rock & Alternative", .red),
        ("R&B & Soul", .blue),
        ("Hip-Hop & Rap", .orange),
        ("Jazz & Blues", .brown),
        ("Acoustic & Unplugged", .teal),
        ("Indie & Senja", .teal),
        ("Metal & Hardcore", .black),
        ("K-Pop", .pink),
        ("J-Pop & Anime", .cyan),
        ("Classical & Instrumental", .gray),
        ("Electronic & Dance", .purple),
        ("Country & Folk", .brown),
        ("90s & 2000s Nostalgia", .mint),
        ("Viral & TikTok Hits", .red),
        ("Sleep & Meditation", .purple),
        ("Sad & Melancholy", .blue),
        ("Pop Punk & Emo", .pink),
        ("Reggae & Ska", .green),
        ("Latin & Reggaeton", .orange),
        ("Afrobeats", .yellow),
        ("Lo-Fi Beats", .indigo),
        ("Gospel & Rohani", .mint),
        ("Musik Religi & Islami", .teal),
        ("Keroncong & Tradisional", .brown),
        ("Pop Daerah (Jawa, Sunda, Batak)", .orange),
        ("Malaysian Pop", .cyan),
        ("Thai & C-Pop", .red),
        ("OST & Soundtracks", .gray),
        ("Gaming", .purple),
        ("Kids & Family", .yellow),
        ("Blues Rock", .blue),
        ("Funk & Disco", .pink),
        ("80s Classics", .mint),
        ("70s Classics", .brown),
        ("Wedding & Love Songs", .pink),
        ("Rainy Day", .gray),
        ("Road Trip", .orange),
        ("Coffee Shop", .brown)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // MARK: - 1. Top 3 YouTube Music Category Cards
                    topNavigationCardsSection
                    
                    // MARK: - 2. New Albums & Singles (Clicking navigates to Album Tracklist)
                    newAlbumsSection
                    
                    // MARK: - 3. Trending Ranked Songs (Live YouTube Music 4-row numbered shelf)
                    trendingRankedSection
                    
                    // MARK: - 4. Daily Top Charts (Live daily rankings)
                    dailyTopChartsSection
                    
                    // MARK: - 5. Top Artists Charts (Choose songs by artist)
                    topArtistsSection
                    
                    // MARK: - 6. Moods & Genres Grid (Expanded colored accent strips)
                    moodsAndGenresSection
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
            .task {
                await loadLiveExploreData()
            }
        }
    }
    
    // MARK: - 1. Top 3 YT Music Category Cards
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
    
    // MARK: - 2. New Albums & Singles (Clicking navigates to Album Tracklist)
    private var newAlbumsSection: some View {
        let displayAlbums = liveNewAlbums.isEmpty ? fallbackNewAlbums : liveNewAlbums
        
        return VStack(alignment: .leading, spacing: 14) {
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
                    ForEach(displayAlbums) { item in
                        NavigationLink {
                            PlaylistOrAlbumDetailView(
                                item: item
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    if let url = item.artworkURL {
                                        AsyncImage(url: url) { phase in
                                            if let img = phase.image {
                                                img.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 155, height: 155)
                                                    .clipped()
                                            } else {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .frame(width: 155, height: 155)
                                            }
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 155, height: 155)
                                    }
                                    
                                    // Album badge indicator
                                    Circle()
                                        .fill(Color.black.opacity(0.55))
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image(systemName: "opticaldisc.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.95))
                                        )
                                        .padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(item.subtitle)
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
    
    // MARK: - 3. Trending Ranked Songs (4-row numbered shelf)
    private var trendingRankedSection: some View {
        let displaySongs = liveTrendingSongs.isEmpty ? fallbackTrending : liveTrendingSongs
        let columns = stride(from: 0, to: displaySongs.count, by: 4).map {
            Array(displaySongs.enumerated())[($0)..<min($0 + 4, displaySongs.count)]
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trending")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    engine.setQueue(displaySongs, startIndex: 0)
                    if let first = displaySongs.first {
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
                                        engine.setQueue(displaySongs, startIndex: item.offset)
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
    
    // MARK: - 4. Daily Top Charts Section (Live daily rankings)
    private var dailyTopChartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Top Charts")
                        .font(.system(size: 22, weight: .bold))
                    Text("Updated live every day")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
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
                    ForEach(dailyTopCharts, id: \.title) { chart in
                        NavigationLink {
                            PlaylistOrAlbumDetailView(
                                item: liveChartPlaylists[chart.title].map { live in
                                    SearchResultItem(
                                        id: live.id,
                                        title: chart.title,
                                        subtitle: "Daily Chart • \(live.title)",
                                        type: .playlist,
                                        artist: "YouTube Music",
                                        artworkURL: live.artworkURL,
                                        browseId: live.browseId,
                                        playlistId: live.playlistId ?? live.id
                                    )
                                } ?? SearchResultItem(
                                    id: "chart_\(chart.title)",
                                    title: chart.query,
                                    subtitle: "Daily Chart • \(chart.subtitle)",
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
                                            .foregroundColor(.white.opacity(0.92))
                                        Text("DAILY TOP")
                                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
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
    
    // MARK: - 5. Top Artists Charts (Choose songs by artist)
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Artists Charts")
                        .font(.system(size: 22, weight: .bold))
                    Text("Select an artist to view their songs")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                NavigationLink {
                    CategoryPlaylistsBrowserView(categoryTitle: "Artists")
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
                HStack(spacing: 16) {
                    if liveArtists.isEmpty && isLoadingLive {
                        ForEach(0..<6, id: \.self) { _ in
                            Circle().fill(Color.secondary.opacity(0.18)).frame(width: 90, height: 90)
                        }
                    }
                    ForEach(liveArtists) { artistItem in
                        let artist = (name: artistItem.title, imageURL: artistItem.artworkURL)
                        NavigationLink {
                            PlaylistOrAlbumDetailView(
                                item: SearchResultItem(
                                    id: artistItem.id,
                                    title: artist.name,
                                    subtitle: "Artist • Top songs",
                                    type: .artist,
                                    artist: artist.name,
                                    artworkURL: artist.imageURL,
                                    browseId: artistItem.browseId
                                )
                            )
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    if let url = artist.imageURL {
                                        AsyncImage(url: url) { phase in
                                            if let img = phase.image {
                                                img.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 90, height: 90)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .frame(width: 90, height: 90)
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 90, height: 90)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                
                                Text(artist.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(width: 95)
                                
                                Text("Artist")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 6. Moods & Genres Section (24+ categories)
    private var moodsAndGenresSection: some View {
        let rows = stride(from: 0, to: moodsAndGenres.count, by: 4).map {
            Array(moodsAndGenres[$0..<min($0 + 4, moodsAndGenres.count)])
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
                                    .frame(width: 180, height: 48)
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
    
    // MARK: - Live Data Fetching
    private func loadLiveExploreData() async {
        let client = YTMusicClient.shared
        let year = Calendar.current.component(.year, from: Date())
        
        // All sections are fetched in parallel from live YouTube Music data.
        async let albumsA = (try? client.searchItems(query: "New album releases \(year)", filter: "Albums")) ?? []
        async let albumsB = (try? client.searchItems(query: "New singles this week \(year)", filter: "Albums")) ?? []
        async let albumsC = (try? client.searchItems(query: "Album baru Indonesia \(year)", filter: "Albums")) ?? []
        async let trendA = (try? client.search(query: "Trending songs Indonesia today", filter: "Songs")) ?? []
        async let trendB = (try? client.search(query: "Trending songs global today \(year)", filter: "Songs")) ?? []
        async let artistsA = (try? client.searchItems(query: "Top artists Indonesia \(year)", filter: "Artists")) ?? []
        async let artistsB = (try? client.searchItems(query: "Top artists global charts \(year)", filter: "Artists")) ?? []
        async let charts = loadLiveCharts()
        
        let albums = dedupe(await albumsA + albumsB + albumsC).filter { $0.type == .album }
        let trending = dedupeTracks(await interleave(trendA, trendB))
        var artists = dedupe(await interleave(artistsA, artistsB)).filter { $0.type == .artist }
        if artists.count < 6 { artists = await resolveFallbackArtists() }
        let chartMap = await charts
        
        await MainActor.run {
            if !albums.isEmpty { self.liveNewAlbums = Array(albums.prefix(24)) }
            if !trending.isEmpty { self.liveTrendingSongs = Array(trending.prefix(20)) }
            self.liveArtists = Array(artists.prefix(20))
            self.liveChartPlaylists = chartMap
            self.isLoadingLive = false
        }
    }
    
    /// Resolves every daily chart card to its real, live YouTube Music chart playlist.
    private func loadLiveCharts() async -> [String: SearchResultItem] {
        await withTaskGroup(of: (String, SearchResultItem?).self) { group in
            for chart in dailyTopCharts {
                group.addTask {
                    let items = (try? await YTMusicClient.shared.searchItems(query: chart.query, filter: "Playlists")) ?? []
                    return (chart.title, items.first { ($0.playlistId ?? $0.browseId ?? $0.id).isEmpty == false })
                }
            }
            var map: [String: SearchResultItem] = [:]
            for await (title, item) in group { if let item { map[title] = item } }
            return map
        }
    }
    
    /// Live artist lookups (real names + real artwork + channel browseId) for the seed list.
    private func resolveFallbackArtists() async -> [SearchResultItem] {
        await withTaskGroup(of: (Int, SearchResultItem?).self) { group in
            for (idx, name) in fallbackArtistNames.enumerated() {
                group.addTask {
                    let items = (try? await YTMusicClient.shared.searchItems(query: name, filter: "Artists")) ?? []
                    return (idx, items.first { $0.type == .artist })
                }
            }
            var results: [(Int, SearchResultItem)] = []
            for await (idx, item) in group { if let item { results.append((idx, item)) } }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    private func interleave<T>(_ a: [T], _ b: [T]) -> [T] {
        var out: [T] = []
        for i in 0..<max(a.count, b.count) {
            if i < a.count { out.append(a[i]) }
            if i < b.count { out.append(b[i]) }
        }
        return out
    }
    
    private func dedupe(_ items: [SearchResultItem]) -> [SearchResultItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
    
    private func dedupeTracks(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }
}
