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
    public let streamURL: URL?
    public let source: TrackSource?
    public let sourceId: String?
    
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
        duration: TimeInterval = 0,
        streamURL: URL? = nil,
        source: TrackSource? = nil,
        sourceId: String? = nil
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
        self.streamURL = streamURL
        self.source = source
        self.sourceId = sourceId
    }
    
    public var asTrack: Track {
        var resolvedArtist: String
        if let explicitArtist = artist, !explicitArtist.trimmingCharacters(in: .whitespaces).isEmpty, explicitArtist != "Unknown Artist" {
            resolvedArtist = explicitArtist.trimmingCharacters(in: .whitespaces)
        } else {
            resolvedArtist = SearchResultItem.extractArtist(from: subtitle, type: type)
        }
        
        // Secondary title fallback: Extract "Artist - Title" (standard YouTube title naming)
        if resolvedArtist == "Unknown Artist" || resolvedArtist.isEmpty {
            for separator in [" - ", " – ", " — "] {
                if let sepRange = title.range(of: separator) {
                    let cand = String(title[..<sepRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !cand.isEmpty && cand.count > 1 {
                        resolvedArtist = cand
                        break
                    }
                }
            }
        }
        
        if resolvedArtist == "Unknown Artist" && (source == .youtube || type == .video) {
            resolvedArtist = "YouTube"
        }
        
        let resolvedAlbum: String
        if let explicitAlbum = album, !explicitAlbum.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedAlbum = explicitAlbum.trimmingCharacters(in: .whitespaces)
        } else if type == .album {
            resolvedAlbum = title
        } else if type == .video {
            resolvedAlbum = "YouTube Video"
        } else if let extracted = SearchResultItem.extractAlbum(from: subtitle) {
            resolvedAlbum = extracted
        } else {
            resolvedAlbum = source == .library ? "Local Library" : "YouTube Music"
        }
        
        let resolvedArtworkURL: URL?
        if let art = artworkURL {
            resolvedArtworkURL = art
        } else if let vId = videoId, vId.count == 11, !vId.hasPrefix("yt_") {
            resolvedArtworkURL = URL(string: "https://i.ytimg.com/vi/\(vId)/hqdefault.jpg")
        } else if id.count == 11 && !id.hasPrefix("yt_") && !id.hasPrefix("local_") {
            resolvedArtworkURL = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        } else {
            resolvedArtworkURL = nil
        }
        
        return Track(
            id: videoId ?? id,
            title: title,
            artist: resolvedArtist,
            album: resolvedAlbum,
            duration: duration > 0 ? duration : 210,
            artworkURL: resolvedArtworkURL,
            streamURL: streamURL,
            isLossless: true,
            source: source,
            sourceId: sourceId
        )
    }
    
    public static func extractArtist(from subtitle: String, type: SearchResultType) -> String {
        let normalized = subtitle
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "·", with: "•")
            .replacingOccurrences(of: "•", with: " • ")
            .replacingOccurrences(of: "  ", with: " ")
            
        let parts = normalized.components(separatedBy: " • ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "Unknown Artist" }
        
        let badgeKeywords: Set<String> = [
            "lagu", "song", "video", "album", "artis", "artist", "playlist", "daftar putar", "single", "ep", "profil", "audio", "official"
        ]
        
        for candidate in parts {
            let lower = candidate.lowercased()
            if badgeKeywords.contains(lower) { continue }
            if lower.contains("ditonton") || lower.contains("pemutaran") || lower.contains("views") || lower.contains("view") || lower.contains("audiens") || lower.contains("penayangan") { continue }
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
