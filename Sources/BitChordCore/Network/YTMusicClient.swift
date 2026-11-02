import Foundation

public actor YTMusicClient {
    public static let shared = YTMusicClient()
    private let session: URLSession
    
    // Fast reliable Piped and Invidious instances
    private let pipedInstances = [
        "https://api.piped.privacydev.net",
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.tokhmi.xyz"
    ]
    
    private let invidiousInstances = [
        "https://invidious.nerdvpn.de",
        "https://inv.tux.pizza",
        "https://invidious.drgns.space"
    ]
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Multi-source resilient music search:
    /// 1. Tries Piped Music API (returns exact YouTube video IDs + tracks)
    /// 2. Tries Invidious API
    /// 3. Tries iTunes Music Search API (high-res Apple Music artwork & metadata + direct preview)
    /// 4. Tries YouTube Innertube
    public func search(query: String, filter: String? = nil) async throws -> [Track] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        // Strategy 1: Piped Music Search (YouTube Music catalog)
        if let pipedResults = await searchViaPiped(query: trimmedQuery), !pipedResults.isEmpty {
            return pipedResults
        }
        
        // Strategy 2: Invidious Search
        if let invidiousResults = await searchViaInvidious(query: trimmedQuery), !invidiousResults.isEmpty {
            return invidiousResults
        }
        
        // Strategy 3: iTunes Search API (High-res metadata & instant playback fallback)
        if let itunesResults = await searchViaITunes(query: trimmedQuery), !itunesResults.isEmpty {
            return itunesResults
        }
        
        // Strategy 4: Direct Innertube Search
        return await searchViaInnertube(query: trimmedQuery)
    }
    
    // MARK: - 1. Piped Music Search
    private func searchViaPiped(query: String) async -> [Track]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        
        for base in pipedInstances {
            guard let url = URL(string: "\(base)/search?q=\(encoded)&filter=music_songs") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 5.0
            
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]] else {
                    continue
                }
                
                var tracks: [Track] = []
                for item in items {
                    guard let title = item["title"] as? String,
                          let rawUrl = item["url"] as? String else { continue }
                    
                    let videoId = rawUrl.replacingOccurrences(of: "/watch?v=", with: "")
                    let artist = item["uploaderName"] as? String ?? "Unknown Artist"
                    let duration = TimeInterval(item["duration"] as? Int ?? 180)
                    let thumbUrlString = item["thumbnail"] as? String
                    let artworkURL = thumbUrlString != nil ? URL(string: thumbUrlString!) : nil
                    
                    tracks.append(
                        Track(
                            id: videoId,
                            title: title,
                            artist: artist,
                            album: "YouTube Music",
                            duration: duration,
                            artworkURL: artworkURL,
                            streamURL: nil,
                            isLossless: true
                        )
                    )
                }
                if !tracks.isEmpty {
                    return tracks
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    // MARK: - 2. Invidious Search
    private func searchViaInvidious(query: String) async -> [Track]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        
        for base in invidiousInstances {
            guard let url = URL(string: "\(base)/api/v1/search?q=\(encoded)&type=video") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 5.0
            
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    continue
                }
                
                var tracks: [Track] = []
                for item in items {
                    guard let title = item["title"] as? String,
                          let videoId = item["videoId"] as? String else { continue }
                    
                    let artist = item["author"] as? String ?? "Unknown Artist"
                    let duration = TimeInterval(item["lengthSeconds"] as? Int ?? 180)
                    var artworkURL: URL? = nil
                    if let thumbs = item["videoThumbnails"] as? [[String: Any]],
                       let first = thumbs.first, let u = first["url"] as? String {
                        artworkURL = URL(string: u)
                    }
                    
                    tracks.append(
                        Track(
                            id: videoId,
                            title: title,
                            artist: artist,
                            album: "YouTube Music",
                            duration: duration,
                            artworkURL: artworkURL,
                            streamURL: nil,
                            isLossless: false
                        )
                    )
                }
                if !tracks.isEmpty {
                    return tracks
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    // MARK: - 3. iTunes Search (Apple Music Aesthetics & 100% Reliable Metadata)
    private func searchViaITunes(query: String) async -> [Track]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=25") else {
            return nil
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 5.0
        
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return nil
            }
            
            var tracks: [Track] = []
            for item in results {
                guard let title = item["trackName"] as? String,
                      let artist = item["artistName"] as? String else { continue }
                
                let trackId = "\(item["trackId"] as? Int ?? UUID().hashValue)"
                let album = item["collectionName"] as? String ?? ""
                let millis = item["trackTimeMillis"] as? Double ?? 180000
                let duration = millis / 1000.0
                
                var artworkURL: URL? = nil
                if let thumb = item["artworkUrl100"] as? String {
                    // Replace 100x100 with 600x600 for crisp Apple Music artwork
                    let highRes = thumb.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                    artworkURL = URL(string: highRes)
                }
                
                var streamURL: URL? = nil
                if let preview = item["previewUrl"] as? String {
                    streamURL = URL(string: preview)
                }
                
                tracks.append(
                    Track(
                        id: trackId,
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        artworkURL: artworkURL,
                        streamURL: streamURL,
                        isLossless: true
                    )
                )
            }
            return tracks
        } catch {
            return nil
        }
    }
    
    // MARK: - 4. Innertube Web/iOS Search
    private func searchViaInnertube(query: String) async -> [Track] {
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.29.1",
                    "deviceModel": "iPhone16,2",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]
        
        var request = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/search")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtube/19.29.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 6.0
        
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }
        
        return parseSearchResults(data: data)
    }
    
    private func parseSearchResults(data: Data) -> [Track] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var results: [Track] = []
        if let contents = json["contents"] as? [String: Any],
           let sectionList = contents["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            for section in sections {
                if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                   let contentsArray = itemSection["contents"] as? [[String: Any]] {
                    for item in contentsArray {
                        if let videoRenderer = item["videoRenderer"] as? [String: Any],
                           let videoId = videoRenderer["videoId"] as? String,
                           let titleObj = videoRenderer["title"] as? [String: Any],
                           let runs = titleObj["runs"] as? [[String: Any]],
                           let title = runs.first?["text"] as? String {
                            
                            var artist = "Unknown Artist"
                            if let ownerText = videoRenderer["ownerText"] as? [String: Any],
                               let ownerRuns = ownerText["runs"] as? [[String: Any]],
                               let aName = ownerRuns.first?["text"] as? String {
                                artist = aName
                            }
                            
                            results.append(
                                Track(
                                    id: videoId,
                                    title: title,
                                    artist: artist,
                                    album: "YouTube Music",
                                    duration: 180,
                                    isLossless: false
                                )
                            )
                        }
                    }
                }
            }
        }
        return results
    }
}
