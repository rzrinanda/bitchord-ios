import Foundation

public struct LyricSyllable: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(startTime)-\(text)" }
    public let text: String
    public let startTime: TimeInterval
    public let duration: TimeInterval
    
    public init(text: String, startTime: TimeInterval, duration: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.duration = duration
    }
}

public struct LyricLine: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(timestamp)-\(text)" }
    public let timestamp: TimeInterval
    public let text: String
    public let translation: String?
    public let syllables: [LyricSyllable]
    public let isInstrumental: Bool
    
    public init(
        timestamp: TimeInterval,
        text: String,
        translation: String? = nil,
        syllables: [LyricSyllable] = [],
        isInstrumental: Bool = false
    ) {
        self.timestamp = timestamp
        self.text = text
        self.translation = translation
        self.syllables = syllables
        self.isInstrumental = isInstrumental
    }
}

public enum LyricsSource: String, Codable, Sendable {
    case localDisk = "Local Storage"
    case memoryCache = "In-Memory Session"
    case network = "Online Stream"
    case embedded = "Embedded Audio Tags"
}

public struct Lyrics: Identifiable, Hashable, Codable, Sendable {
    public var id: String { trackId }
    public let trackId: String
    public let isSynced: Bool
    public let lines: [LyricLine]
    public let plainLyrics: String
    public let provider: String
    public var source: LyricsSource
    public let cachedAt: Date?
    
    public init(
        trackId: String,
        isSynced: Bool,
        lines: [LyricLine],
        plainLyrics: String = "",
        provider: String = "LRCLIB",
        source: LyricsSource = .network,
        cachedAt: Date? = nil
    ) {
        self.trackId = trackId
        self.isSynced = isSynced
        self.lines = lines
        self.plainLyrics = plainLyrics
        self.provider = provider
        self.source = source
        self.cachedAt = cachedAt
    }
    
    /// Finds the index of the line active at the specified playback timestamp
    public func activeLineIndex(for timestamp: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        
        var activeIndex: Int?
        for (index, line) in lines.enumerated() {
            if line.timestamp <= timestamp {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }
}
