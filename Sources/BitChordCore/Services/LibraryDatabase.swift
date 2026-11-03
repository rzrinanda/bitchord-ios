import Foundation

@MainActor
public final class LibraryDatabase: ObservableObject {
    public static let shared = LibraryDatabase()
    
    @Published public private(set) var likedTracks: [Track] = []
    @Published public private(set) var userPlaylists: [Playlist] = []
    @Published public private(set) var recentTracks: [Track] = []
    @Published public private(set) var recentSearches: [Track] = []
    @Published public var totalMinutesListened: Int = 62
    
    private let likedKey = "BitChord.Library.LikedTracks"
    private let playlistsKey = "BitChord.Library.Playlists"
    private let recentsKey = "BitChord.Library.Recents"
    private let recentSearchesKey = "BitChord.Library.RecentSearches"
    private let minutesKey = "BitChord.Library.MinutesListened"
    
    public init() {
        loadData()
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
           let recents = try? decoder.decode([Track].self, from: data) {
            self.recentTracks = recents
        }
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let searches = try? decoder.decode([Track].self, from: data) {
            self.recentSearches = searches
        } else {
            // Default seed matching user's car HU search history (Photo 2)
            self.recentSearches = [
                Track(
                    id: "b_H_y2fHqZs",
                    title: "Yang Terdalam",
                    artist: "NOAH",
                    album: "Taman Langit",
                    duration: 198,
                    artworkURL: URL(string: "https://i.ytimg.com/vi/b_H_y2fHqZs/hqdefault.jpg"),
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
        totalMinutesListened += max(1, Int(track.duration / 60))
        UserDefaults.standard.set(totalMinutesListened, forKey: minutesKey)
    }
    
    // MARK: - Recent Searches
    public func addRecentSearch(track: Track) {
        recentSearches.removeAll(where: { $0.id == track.id || $0.title == track.title })
        recentSearches.insert(track, at: 0)
        if recentSearches.count > 20 {
            recentSearches.removeLast()
        }
        saveRecentSearches()
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
