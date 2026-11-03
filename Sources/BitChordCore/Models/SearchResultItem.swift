import Foundation

public enum SearchResultType: String, Codable, CaseIterable, Sendable {
    case song = "Song"
    case video = "Video"
    case album = "Album"
    case artist = "Artist"
    case playlist = "Playlist"
}

public struct SearchResultItem: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let type: SearchResultType
    public let artworkURL: URL?
    public let videoId: String?
    public let browseId: String?
    public let playlistId: String?
    public let duration: TimeInterval
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        type: SearchResultType,
        artworkURL: URL? = nil,
        videoId: String? = nil,
        browseId: String? = nil,
        playlistId: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.artworkURL = artworkURL
        self.videoId = videoId
        self.browseId = browseId
        self.playlistId = playlistId
        self.duration = duration
    }
    
    public var asTrack: Track {
        let cleanArtist: String
        let parts = subtitle.components(separatedBy: " • ")
        if parts.count >= 2 {
            cleanArtist = parts[1]
        } else {
            cleanArtist = subtitle
        }
        
        return Track(
            id: videoId ?? id,
            title: title,
            artist: cleanArtist,
            album: type == .album ? title : "YouTube Music",
            duration: duration > 0 ? duration : 210,
            artworkURL: artworkURL,
            streamURL: nil,
            isLossless: true
        )
    }
}
