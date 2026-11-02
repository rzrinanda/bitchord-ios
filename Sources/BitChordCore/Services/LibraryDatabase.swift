import Foundation

@MainActor
public final class LibraryDatabase: ObservableObject {
    public static let shared = LibraryDatabase()
    
    @Published public private(set) var likedTracks: [Track] = []
    @Published public private(set) var userPlaylists: [Playlist] = []
    @Published public private(set) var recentTracks: [Track] = []
    
    private let likedKey = "BitChord.Library.LikedTracks"
    private let playlistsKey = "BitChord.Library.Playlists"
    private let recentsKey = "BitChord.Library.Recents"
    
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
    }
}
