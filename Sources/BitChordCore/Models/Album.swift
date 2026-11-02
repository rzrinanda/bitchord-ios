import Foundation

public struct Album: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let year: String?
    public let artworkURL: URL?
    public let trackCount: Int
    public var tracks: [Track]
    
    public init(
        id: String,
        title: String,
        artist: String,
        year: String? = nil,
        artworkURL: URL? = nil,
        trackCount: Int = 0,
        tracks: [Track] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkURL = artworkURL
        self.trackCount = trackCount
        self.tracks = tracks
    }
}

public struct Artist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let artworkURL: URL?
    public let description: String?
    public var topTracks: [Track]
    public var albums: [Album]
    
    public init(
        id: String,
        name: String,
        artworkURL: URL? = nil,
        description: String? = nil,
        topTracks: [Track] = [],
        albums: [Album] = []
    ) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.description = description
        self.topTracks = topTracks
        self.albums = albums
    }
}

public struct Playlist: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let description: String?
    public let artworkURL: URL?
    public var tracks: [Track]
    
    public init(
        id: String,
        title: String,
        author: String = "BitChord",
        description: String? = nil,
        artworkURL: URL? = nil,
        tracks: [Track] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.artworkURL = artworkURL
        self.tracks = tracks
    }
}
