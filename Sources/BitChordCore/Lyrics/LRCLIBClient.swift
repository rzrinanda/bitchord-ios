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
    
    /// Fetches lyrics from LRCLIB using resilient fuzzy track and artist matching
    public func fetchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBResponse {
        let cleanTrack = trackName
            .replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[.*\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        let cleanArtist = artistName
            .components(separatedBy: " ft.")[0]
            .components(separatedBy: " feat.")[0]
            .components(separatedBy: " &")[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        // Strategy 1: Direct get with clean terms
        var components = URLComponents(url: baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: cleanTrack),
            URLQueryItem(name: "artist_name", value: cleanArtist)
        ]
        if let album = albumName, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = queryItems
        
        if let url = components.url {
            var request = URLRequest(url: url)
            request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5.0
            
            if let (data, response) = try? await session.data(for: request),
               let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
               let item = try? JSONDecoder().decode(LRCLIBResponse.self, from: data),
               item.syncedLyrics != nil || item.plainLyrics != nil {
                return item
            }
        }
        
        // Strategy 2: Flexible search query fallback
        return try await searchLyricsFallback(query: "\(cleanArtist) \(cleanTrack)")
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
