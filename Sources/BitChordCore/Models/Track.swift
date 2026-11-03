import Foundation

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var artworkURL: URL?
    public var streamURL: URL?
    public var isLossless: Bool
    public var sampleRate: Double?
    public var bitDepth: Int?
    public var lyricsId: String?
    public var isExplicit: Bool
    
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
    
    /// Display badge formatted cleanly for Now Playing UI matching reference screenshots
    public var displayAudioQualityBadge: String {
        if isLossless {
            if (sampleRate ?? 0) > 48000 || (bitDepth ?? 0) > 16 {
                return "Hi-Res Lossless"
            }
            return "Lossless"
        }
        return "High Quality"
    }
}
