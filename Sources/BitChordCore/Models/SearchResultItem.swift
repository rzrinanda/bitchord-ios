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
    public let artist: String?
    public let album: String?
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
        artist: String? = nil,
        album: String? = nil,
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
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.videoId = videoId
        self.browseId = browseId
        self.playlistId = playlistId
        self.duration = duration
    }
    
    public var asTrack: Track {
        let resolvedArtist: String
        if let explicitArtist = artist, !explicitArtist.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedArtist = explicitArtist.trimmingCharacters(in: .whitespaces)
        } else {
            resolvedArtist = SearchResultItem.extractArtist(from: subtitle, type: type)
        }
        
        let resolvedAlbum: String
        if let explicitAlbum = album, !explicitAlbum.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedAlbum = explicitAlbum.trimmingCharacters(in: .whitespaces)
        } else if type == .album {
            resolvedAlbum = title
        } else if let extracted = SearchResultItem.extractAlbum(from: subtitle) {
            resolvedAlbum = extracted
        } else {
            resolvedAlbum = "YouTube Music"
        }
        
        return Track(
            id: videoId ?? id,
            title: title,
            artist: resolvedArtist,
            album: resolvedAlbum,
            duration: duration > 0 ? duration : 210,
            artworkURL: artworkURL,
            streamURL: nil,
            isLossless: true
        )
    }
    
    public static func extractArtist(from subtitle: String, type: SearchResultType) -> String {
        let parts = subtitle.components(separatedBy: " • ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "Unknown Artist" }
        
        let badgeKeywords: Set<String> = [
            "lagu", "song", "video", "album", "artis", "artist", "playlist", "daftar putar", "single", "ep"
        ]
        
        // If the first part is a category/type badge (e.g. "Lagu • Ada Band • ..."):
        if badgeKeywords.contains(parts[0].lowercased()) {
            if parts.count >= 2 {
                return parts[1]
            } else {
                return "Unknown Artist"
            }
        }
        
        // If first part is not a category badge, it is directly the artist name (e.g. "Ada Band • Heaven Of Love • 4.18"):
        return parts[0]
    }
    
    public static func extractAlbum(from subtitle: String) -> String? {
        let parts = subtitle.components(separatedBy: " • ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        
        let badgeKeywords: Set<String> = [
            "lagu", "song", "video", "album", "artis", "artist", "playlist", "daftar putar", "single", "ep"
        ]
        
        let candidate: String
        if badgeKeywords.contains(parts[0].lowercased()) {
            guard parts.count >= 3 else { return nil }
            candidate = parts[2]
        } else {
            candidate = parts[1]
        }
        
        let lower = candidate.lowercased()
        if lower.contains("ditonton") || lower.contains("pemutaran") || lower.contains("views") || lower.contains("view") {
            return nil
        }
        if candidate.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) != nil {
            return nil // Duration like 4.18 or 3:45
        }
        if candidate.range(of: #"^\d{4}$"#, options: .regularExpression) != nil {
            return nil // Year like 2004
        }
        
        return candidate
    }
}
