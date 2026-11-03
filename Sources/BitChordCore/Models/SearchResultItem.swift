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
            "lagu", "song", "video", "album", "artis", "artist", "playlist", "daftar putar", "single", "ep", "profil"
        ]
        
        for candidate in parts {
            let lower = candidate.lowercased()
            if badgeKeywords.contains(lower) { continue }
            if lower.contains("ditonton") || lower.contains("pemutaran") || lower.contains("views") || lower.contains("view") || lower.contains("audiens") { continue }
            if candidate.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) != nil { continue }
            if candidate.range(of: #"^\d{4}$"#, options: .regularExpression) != nil { continue }
            return candidate
        }
        return "Unknown Artist"
    }
    
    public static func extractAlbum(from subtitle: String) -> String? {
        let parts = subtitle.components(separatedBy: " • ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        
        let badgeKeywords: Set<String> = [
            "lagu", "song", "video", "album", "artis", "artist", "playlist", "daftar putar", "single", "ep", "profil"
        ]
        
        var validCandidates: [String] = []
        for part in parts {
            let lower = part.lowercased()
            if badgeKeywords.contains(lower) { continue }
            if lower.contains("ditonton") || lower.contains("pemutaran") || lower.contains("views") || lower.contains("view") || lower.contains("audiens") { continue }
            if part.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) != nil { continue }
            if part.range(of: #"^\d{4}$"#, options: .regularExpression) != nil { continue }
            validCandidates.append(part)
        }
        
        if validCandidates.count >= 2 {
            return validCandidates[1]
        }
        return nil
    }
}
