import Foundation

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let artworkURL: URL?
    public var streamURL: URL?
    public let isLossless: Bool
    public let sampleRate: Double?
    public let bitDepth: Int?
    public let lyricsId: String?
    public let isExplicit: Bool
    
    public init(
        id: String,
        title: String,
        artist: String,
        album: String = "",
        duration: TimeInterval,
        artworkURL: URL? = nil,
        streamURL: URL? = nil,
        isLossless: Bool = false,
        sampleRate: Double? = nil,
        bitDepth: Int? = nil,
        lyricsId: String? = nil,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.streamURL = streamURL
        self.isLossless = isLossless
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.lyricsId = lyricsId
        self.isExplicit = isExplicit
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var audioBadge: String {
        if isLossless {
            if let rate = sampleRate, let depth = bitDepth, rate > 48000 {
                return String(format: "HI-RES LOSSLESS %d-bit/%.1f kHz", depth, rate / 1000.0)
            }
            return "LOSSLESS"
        }
        return "AAC"
    }
}
