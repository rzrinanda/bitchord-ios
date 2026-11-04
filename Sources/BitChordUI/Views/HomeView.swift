import SwiftUI

public struct HomeView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showingAccountMenu: Bool = false
    @State private var selectedTrackForMenu: Track? = nil
    @State private var selectedMoodChip: String = "All"
    @State private var showingListenTogetherSheet: Bool = false
    @State private var listenTogetherRoomCode: String = ""
    @State private var hostedRoomCode: String? = nil
    
    private let moodChips: [String] = [
        "All", "Energize", "Relax", "Workout", "Commute", "Focus", "Romance", "Sleep", "Party"
    ]
    
    // Quick Picks (YouTube Music 4-row horizontal paging grid)
    private let quickPicks: [Track] = [
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
            id: "CNbmVEEW-mA",
            title: "Yang Terdalam",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 198,
            artworkURL: URL(string: "https://i.ytimg.com/vi/CNbmVEEW-mA/hqdefault.jpg"),
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
            id: "4NRXx6U8ABQ",
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            duration: 200,
            artworkURL: URL(string: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    // New Releases (Albums & Singles)
    private let newReleases: [Track] = [
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
            album: "HIT ME HARD AND SOFT",
            duration: 210,
            artworkURL: URL(string: "https://i.ytimg.com/vi/V9PVRfjEBTI/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "eVli-tstM5E",
            title: "Espresso",
            artist: "Sabrina Carpenter",
            album: "Short n' Sweet",
            duration: 175,
            artworkURL: URL(string: "https://i.ytimg.com/vi/eVli-tstM5E/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "H5v3kku4y6Q",
            title: "As It Was",
            artist: "Harry Styles",
            album: "Harry's House",
            duration: 167,
            artworkURL: URL(string: "https://i.ytimg.com/vi/H5v3kku4y6Q/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "34Na4j8AVgA",
            title: "Starboy (Deluxe)",
            artist: "The Weeknd",
            album: "Album • Hi-Res",
            duration: 230,
            artworkURL: URL(string: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    // Forgotten Favorites
    private let forgottenFavorites: [Track] = [
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
            id: "5NV6Rdv1a3I",
            title: "Get Lucky",
            artist: "Daft Punk",
            album: "Random Access Memories",
            duration: 248,
            artworkURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "fJ9rUzIMcZQ",
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            duration: 354,
            artworkURL: URL(string: "https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "hTWKbfoikeg",
            title: "Smells Like Teen Spirit",
            artist: "Nirvana",
            album: "Nevermind",
            duration: 301,
            artworkURL: URL(string: "https://i.ytimg.com/vi/hTWKbfoikeg/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    // Mixed for You / Radio Stations
    private let mixedStations: [(title: String, subtitle: String, gradient: [Color], seedTrackIndex: Int)] = [
        ("Supermix", "NOAH, Dewa 19, The Weeknd & more", [Color(red: 0.90, green: 0.15, blue: 0.35), Color(red: 0.35, green: 0.10, blue: 0.55)], 0),
        ("My Mix 1", "Indonesian Pop & Rock Legends", [Color(red: 0.12, green: 0.65, blue: 0.85), Color(red: 0.08, green: 0.20, blue: 0.48)], 1),
        ("My Mix 2", "Synthwave, Electronic & Global Hits", [Color(red: 0.95, green: 0.50, blue: 0.15), Color(red: 0.55, green: 0.12, blue: 0.25)], 4),
        ("Chill Mix", "Late Night Acoustic & Melodic Vibes", [Color(red: 0.18, green: 0.72, blue: 0.52), Color(red: 0.06, green: 0.28, blue: 0.25)], 3)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // MARK: - 1. YouTube Music Mood Filter Chips
                    moodFilterBar
                    
                    // MARK: - 2. Continue Listening / Recent Play Card (Shows last played track & timestamp)
                    if let recentTrack = engine.currentTrack ?? library.recentTracks.first {
                        continueListeningCard(for: recentTrack)
                    }
                    
                    // MARK: - 3. Quick Picks (YouTube Music 4-row horizontal grid + Play All)
                    quickPicksSection
                    
                    // MARK: - 4. Station & Listen Together (Interactive Radio + Live Session Card)
                    stationListenTogetherSection
                    
                    // MARK: - 5. New Releases (Albums & Singles)
                    horizontalAlbumsSection(
                        eyebrow: "FRESH DROPS",
                        title: "New releases",
                        tracks: newReleases
                    )
                    
                    // MARK: - 6. Forgotten Favorites
                    horizontalAlbumsSection(
                        eyebrow: "REDISCOVER",
                        title: "Forgotten favorites",
                        tracks: forgottenFavorites
                    )
                    
                    // MARK: - 7. Mixed for You (Personalized YT Music Mixes)
                    mixedForYouSection
                    
                    // MARK: - 8. Listen Again (Recent History Shelf)
                    if !library.recentTracks.isEmpty {
                        horizontalAlbumsSection(
                            eyebrow: "YOUR HISTORY",
                            title: "Listen again",
                            tracks: library.recentTracks
                        )
                    }
                    
                    Spacer(minLength: 110)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        BitChordLogoView(size: 26, cornerRadius: 6)
                        Text("BitChord")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingListenTogetherSheet = true
                        } label: {
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(Circle())
                        }
                        
                        Button {
                            showingAccountMenu = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.85))
                                    .frame(width: 32, height: 32)
                                Text(accountManager.activeAccount.avatarLetter)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
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
            .sheet(isPresented: $showingListenTogetherSheet) {
                listenTogetherSheetView
            }
        }
    }
    
    // MARK: - 1. Mood Filter Chips Bar
    private var moodFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(moodChips, id: \.self) { mood in
                    let isSelected = selectedMoodChip == mood
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMoodChip = mood
                        }
                        if mood != "All" {
                            playMoodCategory(mood)
                        }
                    } label: {
                        Text(mood)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .black : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                    ? Color.white
                                    : Color.secondary.opacity(0.14)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 2. Continue Listening / Recent Play Card
    private func continueListeningCard(for track: Track) -> some View {
        let pos: TimeInterval = (engine.currentTrack?.id == track.id && engine.currentTime > 0)
            ? engine.currentTime
            : library.lastPlaybackPosition
        let dur: TimeInterval = (engine.currentTrack?.id == track.id && engine.duration > 0)
            ? engine.duration
            : (library.lastPlaybackDuration > 0 ? library.lastPlaybackDuration : track.duration)
        let progress = dur > 0 ? min(1.0, max(0.0, pos / dur)) : 0.0
        let isPlayingNow = engine.currentTrack?.id == track.id && engine.status == .playing
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("RECENT PLAY • CONTINUE LISTENING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                }
                Spacer()
                if let playedDate = library.lastPlayedAt {
                    Text(relativeTimeString(from: playedDate))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 14) {
                ZStack(alignment: .center) {
                    if let artURL = track.artworkURL {
                        AsyncImage(url: artURL) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        BitChordLogoView(size: 64, cornerRadius: 12)
                    }
                    
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(track.artist) • \(track.album)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Saved Playback Timestamp & Progress Bar
                    HStack(spacing: 8) {
                        Text("\(formatTimestamp(pos)) / \(formatTimestamp(dur))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Color.cyan)
                                    .frame(width: max(4, geo.size.width * progress), height: 4)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 12)
                    }
                }
                
                Button {
                    resumeRecentTrack(track, at: pos)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isPlayingNow ? "Pause" : "Resume")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 3. Quick Picks Section (YouTube Music 4-Row Horizontal Grid)
    private var quickPicksSection: some View {
        let columns = stride(from: 0, to: quickPicks.count, by: 4).map {
            Array(quickPicks[$0..<min($0 + 4, quickPicks.count)])
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("START RADIO FROM A SONG")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Quick picks")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    engine.setQueue(quickPicks, startIndex: 0)
                    if let first = quickPicks.first {
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
                            ForEach(columns[colIdx]) { track in
                                HStack(spacing: 12) {
                                    Button {
                                        let idx = quickPicks.firstIndex(where: { $0.id == track.id }) ?? 0
                                        engine.setQueue(quickPicks, startIndex: idx)
                                        library.recordPlayback(track: track)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                if let artURL = track.artworkURL {
                                                    AsyncImage(url: artURL) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().aspectRatio(contentMode: .fill)
                                                        } else {
                                                            Color.gray.opacity(0.25)
                                                        }
                                                    }
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                } else {
                                                    BitChordLogoView(size: 50, cornerRadius: 8)
                                                }
                                                
                                                if engine.currentTrack?.id == track.id {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.black.opacity(0.45))
                                                        .frame(width: 50, height: 50)
                                                    Image(systemName: "waveform")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            
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
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        selectedTrackForMenu = track
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(width: 300)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 4. Station & Listen Together Section
    private var stationListenTogetherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE & RADIO SESSIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Station & Listen Together")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Card 1: Station Listen Together (Host or Join Live Sync Room)
                    Button {
                        showingListenTogetherSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("LISTEN TOGETHER", systemImage: "person.2.wave.2.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                                Spacer()
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Spacer()
                            
                            Text("Station Listen Together")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(hostedRoomCode != nil ? "Room Active: #\(hostedRoomCode!) • Tap to manage" : "Stream high-res music in real-time sync with friends")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                        }
                        .padding(16)
                        .frame(width: 250, height: 145)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.15, blue: 0.85), Color(red: 0.15, green: 0.45, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    // Card 2: Personal Lossless Radio Station
                    Button {
                        let seed = engine.currentTrack ?? quickPicks[0]
                        engine.startRadio(for: seed)
                        library.recordPlayback(track: seed)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("INFINITE STATION", systemImage: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Text("Your Personal Radio")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Continuous station tuned to your recent plays & favorites")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                        }
                        .padding(16)
                        .frame(width: 250, height: 145)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.88, green: 0.18, blue: 0.32), Color(red: 0.40, green: 0.08, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 5 & 6. Horizontal Album/Track Shelf (New Releases, Forgotten Favorites, Listen Again)
    private func horizontalAlbumsSection(eyebrow: String, title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    engine.setQueue(tracks, startIndex: 0)
                    if let first = tracks.first {
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
                HStack(spacing: 14) {
                    ForEach(tracks) { track in
                        Button {
                            let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                            engine.setQueue(tracks, startIndex: idx)
                            library.recordPlayback(track: track)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let artURL = track.artworkURL {
                                        AsyncImage(url: artURL) { phase in
                                            if let img = phase.image {
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Color.gray.opacity(0.25)
                                            }
                                        }
                                        .frame(width: 155, height: 155)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        BitChordLogoView(size: 155, cornerRadius: 12)
                                    }
                                    
                                    Circle()
                                        .fill(Color.black.opacity(0.65))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Image(systemName: engine.currentTrack?.id == track.id && engine.status == .playing ? "pause.fill" : "play.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .padding(8)
                                }
                                
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 155)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                engine.insertNextInQueue(track)
                            } label: {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            Button {
                                engine.appendToQueue(track)
                            } label: {
                                Label("Add to Queue", systemImage: "text.badge.plus")
                            }
                            Button {
                                library.toggleLike(track: track)
                            } label: {
                                Label(library.isLiked(trackId: track.id) ? "Unlike" : "Like",
                                      systemImage: library.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 7. Mixed for You Section
    private var mixedForYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MADE FOR YOU")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Mixed for you")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(mixedStations, id: \.title) { mix in
                        Button {
                            let rotated = quickPicks
                            let start = min(mix.seedTrackIndex, max(0, rotated.count - 1))
                            engine.setQueue(rotated, startIndex: start)
                            library.recordPlayback(track: rotated[start])
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomLeading) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: mix.gradient,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 155, height: 155)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Image(systemName: "waveform.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white.opacity(0.9))
                                        Spacer()
                                        Text(mix.title)
                                            .font(.system(size: 18, weight: .heavy))
                                            .foregroundColor(.white)
                                    }
                                    .padding(14)
                                }
                                
                                Text(mix.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(mix.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
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
    
    // MARK: - Listen Together Sheet
    private var listenTogetherSheetView: some View {
        NavigationStack {
            Form {
                Section {
                    if let code = hostedRoomCode {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Room Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(code)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            Spacer()
                            Button("Start Station") {
                                let seed = engine.currentTrack ?? quickPicks[0]
                                engine.setQueue(quickPicks, startIndex: 0)
                                library.recordPlayback(track: seed)
                                showingListenTogetherSheet = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                        }
                    } else {
                        Button {
                            hostedRoomCode = String(Int.random(in: 100000...999999))
                        } label: {
                            Label("Host New Listen Together Station", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                } header: {
                    Text("HOST A STATION")
                } footer: {
                    Text("Generates a 6-digit room code so friends can listen to your queue in real-time sync.")
                }
                
                Section {
                    TextField("Enter 6-digit room code", text: $listenTogetherRoomCode)
                        .keyboardType(.numberPad)
                    Button("Join Friend's Station") {
                        if !listenTogetherRoomCode.trimmingCharacters(in: .whitespaces).isEmpty {
                            hostedRoomCode = listenTogetherRoomCode
                            engine.setQueue(quickPicks, startIndex: 0)
                            showingListenTogetherSheet = false
                        }
                    }
                    .disabled(listenTogetherRoomCode.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("JOIN EXISTING ROOM")
                }
            }
            .navigationTitle("Station Listen Together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingListenTogetherSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func resumeRecentTrack(_ track: Track, at position: TimeInterval) {
        if engine.currentTrack?.id == track.id {
            if engine.status == .playing {
                engine.pause()
            } else {
                if engine.activeBackend == .none && position > 2 {
                    engine.playTrack(at: engine.queueIndex, initialSeek: position)
                } else {
                    engine.resume()
                }
            }
        } else {
            var queueList = library.recentTracks
            if !queueList.contains(where: { $0.id == track.id }) {
                queueList.insert(track, at: 0)
            }
            let idx = queueList.firstIndex(where: { $0.id == track.id }) ?? 0
            engine.setQueue(queueList, startIndex: idx)
            if position > 2 {
                engine.playTrack(at: idx, initialSeek: position)
            }
        }
    }
    
    private func playMoodCategory(_ mood: String) {
        Task {
            let results = (try? await YTMusicClient.shared.search(query: "\(mood) music hits")) ?? []
            await MainActor.run {
                if !results.isEmpty {
                    engine.setQueue(results, startIndex: 0)
                    library.recordPlayback(track: results[0])
                }
            }
        }
    }
    
    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(diff / 60)m ago"
        } else if diff < 86400 {
            return "\(diff / 3600)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM, HH:mm"
            return formatter.string(from: date)
        }
    }
}
