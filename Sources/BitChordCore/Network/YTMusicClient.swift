import Foundation

public actor YTMusicClient {
    public static let shared = YTMusicClient()
    private let session: URLSession
    
    // Innertube Public API key
    private let innertubeKey = "AIzaSyAO_FJ2SlqAE4Anad-CA4Pr-G93427u1r"
    
    // Fast reliable Piped and Invidious instances
    private let pipedInstances = [
        "https://pipedapi.kavin.rocks",
        "https://api.piped.privacydev.net",
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
    
    /// Multi-source resilient high-speed music search:
    /// Queries YouTube Music catalog with official BitChord filter parameters
    public func search(query: String, filter: String? = nil) async throws -> [Track] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        // Query official YouTube Music catalog with exact BitChord filter params
        let ytMusicResults = await searchViaInnertube(query: trimmedQuery, filter: filter)
        if !ytMusicResults.isEmpty {
            return ytMusicResults
        }
        
        // Fallback to iTunes metadata if needed
        if let itunesResults = await searchViaITunes(query: trimmedQuery), !itunesResults.isEmpty {
            return itunesResults
        }
        
        // Fallback to Piped
        if let pipedResults = await searchViaPiped(query: trimmedQuery), !pipedResults.isEmpty {
            return pipedResults
        }
        
        return []
    }
    
    /// Resolves direct YouTube 11-character videoId from track title and artist
    public func resolveYouTubeVideoId(title: String, artist: String?) async -> String? {
        let query = "\(title) \(artist ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "query": query
        ]
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 4.0
        
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return extractFirstVideoId(from: json)
    }
    
    private func extractFirstVideoId(from json: Any) -> String? {
        if let dict = json as? [String: Any] {
            if let vId = dict["videoId"] as? String, vId.count == 11, !vId.hasPrefix("yt_") {
                return vId
            }
            if let watchEndpoint = dict["watchEndpoint"] as? [String: Any],
               let vId = watchEndpoint["videoId"] as? String, vId.count == 11 {
                return vId
            }
            for (_, val) in dict {
                if let found = extractFirstVideoId(from: val) {
                    return found
                }
            }
        } else if let arr = json as? [Any] {
            for item in arr {
                if let found = extractFirstVideoId(from: item) {
                    return found
                }
            }
        }
        return nil
    }
    
    /// Generates radio / autoplay recommendations of similar full-length tracks (Same Vibe & Frequency)
    public func fetchRadioTracks(for track: Track) async -> [Track] {
        let videoId: String
        if track.id.count == 11 && !track.id.hasPrefix("yt_") {
            videoId = track.id
        } else if let resolved = await resolveYouTubeVideoId(title: track.title, artist: track.artist) {
            videoId = resolved
        } else {
            videoId = "R6f_7G71p_w" // Default seed
        }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "videoId": videoId,
            "playlistId": "RDAMVM\(videoId)",
            "isAudioOnly": true
        ]
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/next") else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 6.0
        
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        let radioItems = parsePlaylistPanelVideos(json: json, seedVideoId: videoId)
        if !radioItems.isEmpty {
            return radioItems
        }
        
        // Fallback: search for top tracks by the artist if next endpoint returns empty
        let cleanArtist = track.artist.components(separatedBy: " ft.")[0].components(separatedBy: " feat.")[0]
        if let fallbackTracks = try? await search(query: "\(cleanArtist) popular") {
            return fallbackTracks.filter { $0.id != track.id }
        }
        
        return []
    }
    
    private func parsePlaylistPanelVideos(json: Any, seedVideoId: String) -> [Track] {
        var results: [Track] = []
        
        func extract(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let r = dict["playlistPanelVideoRenderer"] as? [String: Any],
                   let vId = r["videoId"] as? String, vId != seedVideoId {
                    
                    let title = (r["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let songTitle = title?.first?["text"] as? String ?? "Unknown Title"
                    
                    var artistName = "YouTube Music"
                    if let runs = (r["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]] {
                        var artistRuns: [String] = []
                        for run in runs {
                            let t = run["text"] as? String ?? ""
                            if t.contains("•") { break }
                            artistRuns.append(t)
                        }
                        let joined = artistRuns.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !joined.isEmpty { artistName = joined }
                    }
                    
                    var artworkURL: URL? = nil
                    if let thumb = r["thumbnail"] as? [String: Any],
                       let thumbs = thumb["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let u = last["url"] as? String {
                        artworkURL = URL(string: u)
                    }
                    
                    var duration: TimeInterval = 210
                    if let lengthRuns = (r["lengthText"] as? [String: Any])?["runs"] as? [[String: Any]],
                       let text = lengthRuns.first?["text"] as? String {
                        let parts = text.split(separator: ":")
                        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                            duration = m * 60 + s
                        }
                    }
                    
                    results.append(
                        Track(
                            id: vId,
                            title: songTitle,
                            artist: artistName,
                            album: "YouTube Music",
                            duration: duration,
                            artworkURL: artworkURL,
                            isLossless: true
                        )
                    )
                }
                for (_, val) in dict {
                    extract(from: val)
                }
            } else if let arr = obj as? [Any] {
                for it in arr {
                    extract(from: it)
                }
            }
        }
        
        extract(from: json)
        return results
    }
    
    /// Public access for stream fallback resolution
    public func searchViaITunesDirect(query: String) async -> [Track]? {
        return await searchViaITunes(query: query)
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
                
                // Keep streamURL nil so full length audio is extracted from YouTube
                tracks.append(
                    Track(
                        id: trackId,
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        artworkURL: artworkURL,
                        streamURL: nil,
                        isLossless: true
                    )
                )
            }
            return tracks
        } catch {
            return nil
        }
    }
    
    // MARK: - 4. YouTube Music Web Search
    private func searchViaInnertube(query: String, filter: String? = nil) async -> [Track] {
        var body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "query": query
        ]
        
        // Exact filter params matching BitChord Android SearchFilter:
        let filterParam: String? = switch filter?.lowercased() {
        case "songs": "EgWKAQIIAWoKEAkQChAFEAMQBA=="
        case "videos": "EgWKAQIQAWoKEAkQChAFEAMQBA=="
        case "albums": "EgWKAQIYAWoKEAkQChAFEAMQBA=="
        case "artists": "EgWKAQIgAWoKEAkQChAFEAMQBA=="
        case "playlists": "EgWKAQIoAWoKEAkQChAFEAMQBA=="
        default: "EgWKAQIIAWoKEAkQChAFEAMQBA==" // Default to Songs for official tracks
        }
        
        if let param = filterParam {
            body["params"] = param
        }
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5.0
        
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        return parseMusicSearchResults(json: json)
    }
    
    private func parseMusicSearchResults(json: Any) -> [Track] {
        var results: [Track] = []
        
        func extract(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let r = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    var videoId: String? = nil
                    var songTitle = "Unknown"
                    var artistName = "YouTube Music"
                    
                    if let flexColumns = r["flexColumns"] as? [[String: Any]] {
                        for (idx, flex) in flexColumns.enumerated() {
                            if let flexRenderer = flex["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                               let textObj = flexRenderer["text"] as? [String: Any],
                               let runs = textObj["runs"] as? [[String: Any]],
                               let firstRun = runs.first,
                               let t = firstRun["text"] as? String {
                                
                                if idx == 0 {
                                    songTitle = t
                                    if let nav = firstRun["navigationEndpoint"] as? [String: Any],
                                       let watch = nav["watchEndpoint"] as? [String: Any],
                                       let vId = watch["videoId"] as? String {
                                        videoId = vId
                                    }
                                } else if idx == 1 {
                                    artistName = t
                                }
                            }
                        }
                    }
                    
                    if videoId == nil {
                        if let playlistItemData = r["playlistItemData"] as? [String: Any],
                           let vId = playlistItemData["videoId"] as? String {
                            videoId = vId
                        }
                    }
                    
                    var artworkURL: URL? = nil
                    if let thumb = r["thumbnail"] as? [String: Any],
                       let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
                       let thumbObj = musicThumb["thumbnail"] as? [String: Any],
                       let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let u = last["url"] as? String {
                        artworkURL = URL(string: u)
                    }
                    
                    if let vId = videoId, vId.count == 11, !results.contains(where: { $0.id == vId }) {
                        results.append(
                            Track(
                                id: vId,
                                title: songTitle,
                                artist: artistName,
                                album: "YouTube Music",
                                duration: 210,
                                artworkURL: artworkURL,
                                isLossless: true
                            )
                        )
                    }
                }
                for (_, val) in dict {
                    extract(from: val)
                }
            } else if let arr = obj as? [Any] {
                for it in arr {
                    extract(from: it)
                }
            }
        }
        
        extract(from: json)
        return results
    }
}
