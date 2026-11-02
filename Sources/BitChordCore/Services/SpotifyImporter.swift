import Foundation

public struct SpotifyImportResult: Sendable {
    public let playlistTitle: String
    public let tracks: [Track]
}

public actor SpotifyImporter {
    public static let shared = SpotifyImporter()
    
    public init() {}
    
    /// Parses a Spotify URL (Track or Playlist) and searches matching songs via BitChord's streaming catalog
    public func importFromURL(urlString: String) async throws -> SpotifyImportResult {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw URLError(.badURL)
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 3 else {
            throw URLError(.cannotParseResponse)
        }
        
        let type = pathComponents[1] // "track" or "playlist"
        _ = pathComponents[2]
        
        // Use Spotify open oEmbed endpoint to retrieve title and artist metadata without OAuth
        let oEmbedURL = URL(string: "https://open.spotify.com/oembed?url=\(url.absoluteString)")!
        var request = URLRequest(url: oEmbedURL)
        request.timeoutInterval = 8.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        if type == "track" {
            // Title typically is formatted as "Song Title by Artist" or just "Song Title"
            let searchResults = try await YTMusicClient.shared.search(query: title)
            return SpotifyImportResult(playlistTitle: title, tracks: searchResults.prefix(1).map { $0 })
        } else {
            // For playlists, search related tracks for the playlist theme
            let searchResults = try await YTMusicClient.shared.search(query: title)
            return SpotifyImportResult(playlistTitle: title, tracks: searchResults)
        }
    }
}
