import Foundation

public struct LRCLIBResponse: Codable, Sendable {
    public let id: Int?
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?
}

public actor LRCLIBClient {
    public static let shared = LRCLIBClient()
    private let session: URLSession
    private let baseURL = URL(string: "https://lrclib.net/api")!
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches lyrics from LRCLIB using exact track information
    public func fetchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        if let album = albumName, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if let dur = duration, dur > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(dur))))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("BitChord-iOS/1.0 (https://github.com/rzrinanda/bitchord-ios)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Try search fallback if direct get returns 404
            return try await searchLyricsFallback(query: "\(artistName) \(trackName)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(LRCLIBResponse.self, from: data)
    }
    
    /// Search fallback if exact match query failed
    public func searchLyricsFallback(query: String) async throws -> LRCLIBResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let results = try decoder.decode([LRCLIBResponse].self, from: data)
        guard let firstMatch = results.first else {
            throw URLError(.cannotFindHost)
        }
        return firstMatch
    }
}
