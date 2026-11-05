import Foundation

@MainActor
public final class LibraryDatabase: ObservableObject {
    public static let shared = LibraryDatabase()
    
    @Published public private(set) var likedTracks: [Track] = []
    @Published public private(set) var userPlaylists: [Playlist] = []
    @Published public private(set) var recentTracks: [Track] = []
    @Published public private(set) var recentSearches: [Track] = []
    @Published public var totalMinutesListened: Int = 62
    @Published public var lastPlayedAt: Date? = nil
    @Published public var lastPlaybackPosition: TimeInterval = 0
    @Published public var lastPlaybackDuration: TimeInterval = 0
    
    private let likedKey = "BitChord.Library.LikedTracks"
    private let playlistsKey = "BitChord.Library.Playlists"
    private let recentsKey = "BitChord.Library.Recents"
    private let recentSearchesKey = "BitChord.Library.RecentSearches"
    private let minutesKey = "BitChord.Library.MinutesListened"
    private let lastPlayedAtKey = "BitChord.Library.LastPlayedAt"
    private let lastPositionKey = "BitChord.Library.LastPosition"
    private let lastDurationKey = "BitChord.Library.LastDuration"
    
    public init() {
        loadData()
        resolveMissingArtworksInLibrary()
    }
    
    /// Updates the artwork URL for a track across all Library collections (`likedTracks`, `recentTracks`, `recentSearches`, `userPlaylists`).
    public func updateTrackArtwork(trackId: String, title: String? = nil, artworkURL: URL) {
        var didChangeLiked = false
        for i in likedTracks.indices {
            if likedTracks[i].id == trackId || (title != nil && likedTracks[i].title == title) {
                if likedTracks[i].artworkURL != artworkURL {
                    likedTracks[i].artworkURL = artworkURL
                    didChangeLiked = true
                }
            }
        }
        if didChangeLiked { saveLiked() }
        
        var didChangeRecents = false
        for i in recentTracks.indices {
            if recentTracks[i].id == trackId || (title != nil && recentTracks[i].title == title) {
                if recentTracks[i].artworkURL != artworkURL {
                    recentTracks[i].artworkURL = artworkURL
                    didChangeRecents = true
                }
            }
        }
        if didChangeRecents { saveRecents() }
        
        var didChangeSearches = false
        for i in recentSearches.indices {
            if recentSearches[i].id == trackId || (title != nil && recentSearches[i].title == title) {
                if recentSearches[i].artworkURL != artworkURL {
                    recentSearches[i].artworkURL = artworkURL
                    didChangeSearches = true
                }
            }
        }
        if didChangeSearches { saveRecentSearches() }
        
        var didChangePlaylists = false
        for pIdx in userPlaylists.indices {
            for tIdx in userPlaylists[pIdx].tracks.indices {
                if userPlaylists[pIdx].tracks[tIdx].id == trackId || (title != nil && userPlaylists[pIdx].tracks[tIdx].title == title) {
                    if userPlaylists[pIdx].tracks[tIdx].artworkURL != artworkURL {
                        userPlaylists[pIdx].tracks[tIdx].artworkURL = artworkURL
                        didChangePlaylists = true
                    }
                }
            }
        }
        if didChangePlaylists { savePlaylists() }
        
        if AudioPlayerEngine.shared.currentTrack?.id == trackId {
            AudioPlayerEngine.shared.updateCurrentTrackArtwork(artworkURL)
        }
    }
    
    public func resolveMissingArtworksInLibrary() {
        var tracksNeedingArt: [Track] = []
        let all = likedTracks + recentTracks + recentSearches + userPlaylists.flatMap { $0.tracks }
        var seen = Set<String>()
        for t in all {
            if !seen.contains(t.id) && ArtworkResolver.shouldResolveReplacement(for: t.artworkURL) {
                seen.insert(t.id)
                tracksNeedingArt.append(t)
            }
        }
        guard !tracksNeedingArt.isEmpty else { return }
        Task {
            for track in tracksNeedingArt {
                if let resolved = await ArtworkResolver.shared.resolveArtworkURL(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    trackId: track.id,
                    existingURL: track.artworkURL
                ), resolved != track.artworkURL {
                    await MainActor.run {
                        self.updateTrackArtwork(trackId: track.id, title: track.title, artworkURL: resolved)
                    }
                }
            }
        }
    }
    
    private func loadData() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: likedKey),
           let tracks = try? decoder.decode([Track].self, from: data) {
            self.likedTracks = tracks
        }
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let playlists = try? decoder.decode([Playlist].self, from: data) {
            self.userPlaylists = playlists
        }
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let recents = try? decoder.decode([Track].self, from: data),
           !recents.isEmpty {
            self.recentTracks = recents
        } else {
            self.recentTracks = [
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
                )
            ]
        }
        if let savedTime = UserDefaults.standard.object(forKey: lastPlayedAtKey) as? Date {
            self.lastPlayedAt = savedTime
        } else {
            self.lastPlayedAt = Date().addingTimeInterval(-300)
        }
        let savedPos = UserDefaults.standard.double(forKey: lastPositionKey)
        self.lastPlaybackPosition = savedPos > 0 ? savedPos : 84
        let savedDur = UserDefaults.standard.double(forKey: lastDurationKey)
        self.lastPlaybackDuration = savedDur > 0 ? savedDur : (recentTracks.first?.duration ?? 218)
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let searches = try? decoder.decode([Track].self, from: data) {
            self.recentSearches = searches
        } else {
            // Default seed matching user's car HU search history (Photo 2)
            self.recentSearches = [
                Track(
                    id: "CNbmVEEW-mA",
                    title: "Yang Terdalam",
                    artist: "NOAH",
                    album: "Taman Langit",
                    duration: 198,
                    artworkURL: URL(string: "https://i.ytimg.com/vi/CNbmVEEW-mA/hqdefault.jpg"),
                    isLossless: true
                )
            ]
        }
        let storedMinutes = UserDefaults.standard.integer(forKey: minutesKey)
        if storedMinutes > 0 {
            self.totalMinutesListened = storedMinutes
        }
    }
    
    private func saveLiked() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: likedKey)
        }
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(userPlaylists) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
        }
    }
    
    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentTracks) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }
    
    // MARK: - Liked Songs
    public func isLiked(trackId: String) -> Bool {
        return likedTracks.contains(where: { $0.id == trackId })
    }
    
    public func toggleLike(track: Track) {
        if let index = likedTracks.firstIndex(where: { $0.id == track.id }) {
            likedTracks.remove(at: index)
        } else {
            likedTracks.insert(track, at: 0)
            if ArtworkResolver.shouldResolveReplacement(for: track.artworkURL) {
                resolveAndSaveArtwork(for: track)
            }
        }
        saveLiked()
    }
    
    // MARK: - Playlists
    public func createPlaylist(title: String, description: String? = nil) {
        let newPlaylist = Playlist(
            id: UUID().uuidString,
            title: title,
            author: "You",
            description: description,
            tracks: []
        )
        userPlaylists.append(newPlaylist)
        savePlaylists()
    }
    
    public func addTrackToPlaylist(playlistId: String, track: Track) {
        guard let index = userPlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !userPlaylists[index].tracks.contains(where: { $0.id == track.id }) {
            userPlaylists[index].tracks.append(track)
            savePlaylists()
            if ArtworkResolver.shouldResolveReplacement(for: track.artworkURL) {
                resolveAndSaveArtwork(for: track)
            }
        }
    }
    
    public func removeTrackFromPlaylist(playlistId: String, trackId: String) {
        guard let pIndex = userPlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        userPlaylists[pIndex].tracks.removeAll(where: { $0.id == trackId })
        savePlaylists()
    }
    
    // MARK: - Recents
    public func recordPlayback(track: Track) {
        recentTracks.removeAll(where: { $0.id == track.id })
        recentTracks.insert(track, at: 0)
        if recentTracks.count > 30 {
            recentTracks.removeLast()
        }
        saveRecents()
        if ArtworkResolver.shouldResolveReplacement(for: track.artworkURL) {
            resolveAndSaveArtwork(for: track)
        }
        let now = Date()
        self.lastPlayedAt = now
        self.lastPlaybackDuration = track.duration
        UserDefaults.standard.set(now, forKey: lastPlayedAtKey)
        UserDefaults.standard.set(track.duration, forKey: lastDurationKey)
        totalMinutesListened += max(1, Int(track.duration / 60))
        UserDefaults.standard.set(totalMinutesListened, forKey: minutesKey)
    }
    
    public func updateLastPlaybackProgress(position: TimeInterval, duration: TimeInterval) {
        self.lastPlaybackPosition = position
        if duration > 0 {
            self.lastPlaybackDuration = duration
            UserDefaults.standard.set(duration, forKey: lastDurationKey)
        }
        let now = Date()
        self.lastPlayedAt = now
        UserDefaults.standard.set(position, forKey: lastPositionKey)
        UserDefaults.standard.set(now, forKey: lastPlayedAtKey)
    }
    
    // MARK: - Recent Searches
    public func addRecentSearch(track: Track) {
        recentSearches.removeAll(where: { $0.id == track.id || $0.title == track.title })
        recentSearches.insert(track, at: 0)
        if recentSearches.count > 20 {
            recentSearches.removeLast()
        }
        saveRecentSearches()
        if ArtworkResolver.shouldResolveReplacement(for: track.artworkURL) {
            resolveAndSaveArtwork(for: track)
        }
    }
    
    private func resolveAndSaveArtwork(for track: Track) {
        Task {
            if let resolved = await ArtworkResolver.shared.resolveArtworkURL(
                title: track.title,
                artist: track.artist,
                album: track.album,
                trackId: track.id,
                existingURL: track.artworkURL
            ) {
                await MainActor.run {
                    self.updateTrackArtwork(trackId: track.id, title: track.title, artworkURL: resolved)
                }
            }
        }
    }
    
    public func removeRecentSearch(trackId: String) {
        recentSearches.removeAll(where: { $0.id == trackId })
        saveRecentSearches()
    }
    
    public func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        }
    }
}
