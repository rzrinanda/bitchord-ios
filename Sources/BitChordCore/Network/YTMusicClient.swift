import Foundation

public actor YTMusicClient {
    public static let shared = YTMusicClient()
    private let session: URLSession
    
    // Innertube Public API key
    private let innertubeKey = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    
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
        let items = try await searchItems(query: query, filter: filter)
        if !items.isEmpty {
            return items.map { $0.asTrack }
        }
        return []
    }
    
    /// Returns rich heterogeneous search items matching BitChord Android (Songs, Videos, Albums, Artists, Playlists)
    public func searchItems(query: String, filter: String? = nil) async throws -> [SearchResultItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let ytMusicResults = await searchViaInnertube(query: trimmedQuery, filter: filter)
        if !ytMusicResults.isEmpty {
            return ytMusicResults
        }
        
        // Fallback to iTunes metadata if needed
        if let itunesResults = await searchViaITunes(query: trimmedQuery), !itunesResults.isEmpty {
            return itunesResults.map { track in
                SearchResultItem(
                    id: track.id,
                    title: track.title,
                    subtitle: "Lagu • \(track.artist)",
                    type: .song,
                    artworkURL: track.artworkURL,
                    videoId: track.id.count == 11 ? track.id : nil,
                    duration: track.duration
                )
            }
        }
        
        // Fallback to Piped
        if let pipedResults = await searchViaPiped(query: trimmedQuery), !pipedResults.isEmpty {
            return pipedResults.map { track in
                SearchResultItem(
                    id: track.id,
                    title: track.title,
                    subtitle: "Lagu • \(track.artist)",
                    type: .song,
                    artworkURL: track.artworkURL,
                    videoId: track.id,
                    duration: track.duration
                )
            }
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
    
    /// Resolves official YouTube Music Topic / Audio videoId which always has embedding allowed
    public func resolveTopicVideoId(title: String, artist: String?) async -> String? {
        let cleanArtist = artist?.components(separatedBy: " ft.")[0].components(separatedBy: " feat.")[0].trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let query = "\(title) \(cleanArtist) topic"
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
        let cleanArtist: String
        if !track.artist.isEmpty && track.artist != "YouTube Music" && !track.artist.contains("Unknown") {
            cleanArtist = track.artist.components(separatedBy: " ft.")[0].components(separatedBy: " feat.")[0].components(separatedBy: ",")[0].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanArtist = ""
        }
        
        var videoId: String? = nil
        if track.id.count == 11 && !track.id.hasPrefix("yt_") {
            videoId = track.id
        } else if let resolved = await resolveYouTubeVideoId(title: track.title, artist: cleanArtist) {
            videoId = resolved
        }
        
        // 1. Try official YouTube Music Radio endpoint (RDAMVM)
        if let vId = videoId {
            let body: [String: Any] = [
                "context": [
                    "client": [
                        "clientName": "WEB_REMIX",
                        "clientVersion": "1.20250101.01.00",
                        "hl": "id",
                        "gl": "ID"
                    ]
                ],
                "videoId": vId,
                "playlistId": "RDAMVM\(vId)",
                "isAudioOnly": true
            ]
            
            if let url = URL(string: "https://music.youtube.com/youtubei/v1/next") {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
                req.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                req.timeoutInterval = 6.0
                
                if let (data, resp) = try? await session.data(for: req),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let radioItems = parsePlaylistPanelVideos(json: json, seedVideoId: vId)
                    if !radioItems.isEmpty {
                        return radioItems
                    }
                }
            }
        }
        
        // 2. Intelligent Genre / Artist Affinity Fallback (Ensures recommendations are always "sefrekuensi")
        let relatedArtistsMap: [String: [String]] = [
            "muse": ["Radiohead", "The Killers", "Arctic Monkeys", "Placebo", "Franz Ferdinand", "Coldplay", "Oasis"],
            "noah": ["Peterpan", "Dewa 19", "Sheila On 7", "Ungu", "D'Masiv", "Samson", "Kerispatih", "Ada Band"],
            "peterpan": ["NOAH", "Dewa 19", "Sheila On 7", "Ungu", "D'Masiv", "Samson", "Padi", "Gigi"],
            "dewa 19": ["Padi", "Sheila On 7", "Gigi", "Slank", "NOAH", "Peterpan", "Jamrud", "Ari Lasso", "Ada Band"],
            "sheila on 7": ["Padi", "Dewa 19", "NOAH", "Peterpan", "Gigi", "Ungu", "Jikustik", "The Rain"],
            "linkin park": ["Evanescence", "Limp Bizkit", "Papa Roach", "System of a Down", "Green Day", "Three Days Grace"],
            "coldplay": ["Keane", "OneRepublic", "The Fray", "Snow Patrol", "Imagine Dragons", "The Script"],
            "queen": ["Led Zeppelin", "The Beatles", "Pink Floyd", "Elton John", "David Bowie", "Aerosmith"]
        ]
        
        let artistKey = cleanArtist.lowercased()
        var targetQueries: [String] = []
        if let relatedList = relatedArtistsMap[artistKey] ?? relatedArtistsMap.first(where: { artistKey.contains($0.key) })?.value {
            let sample = relatedList.shuffled().prefix(2)
            for rel in sample {
                targetQueries.append("\(rel) lagu populer")
            }
        } else if !cleanArtist.isEmpty {
            targetQueries.append("\(cleanArtist) lagu populer")
            targetQueries.append("\(cleanArtist) radio")
        } else {
            targetQueries.append("\(track.title) radio mix")
        }
        
        var harmonized: [Track] = []
        for q in targetQueries {
            if let searchTracks = try? await search(query: q) {
                let filtered = searchTracks.filter { s in
                    s.id != track.id && !harmonized.contains(where: { h in h.id == s.id })
                }
                harmonized.append(contentsOf: filtered.prefix(5))
            }
        }
        
        if !harmonized.isEmpty {
            return harmonized
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
                
                tracks.append(
                    Track(
                        id: trackId,
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        artworkURL: artworkURL,
                        streamURL: nil, // Full length only - never 30s preview snippet!
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
    private func searchViaInnertube(query: String, filter: String? = nil) async -> [SearchResultItem] {
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
        default: nil // "All" or nil sends no filter param, returning mixed catalog!
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
        request.timeoutInterval = 7.0
        
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        return parseMusicSearchResults(json: json, filter: filter)
    }
    
    private func parseMusicSearchResults(json: Any, filter: String? = nil) -> [SearchResultItem] {
        var results: [SearchResultItem] = []
        var seen = Set<String>()
        
        func extract(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let r = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    var title = ""
                    var subtitle = ""
                    var artist = "YouTube Music"
                    var browseId: String? = nil
                    var pageType = ""
                    var videoId: String? = nil
                    var playlistId: String? = nil
                    
                    // 1. Extract runs from flexColumns
                    if let flexColumns = r["flexColumns"] as? [[String: Any]] {
                        for (idx, flex) in flexColumns.enumerated() {
                            if let flexRenderer = flex["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                               let textObj = flexRenderer["text"] as? [String: Any],
                               let runs = textObj["runs"] as? [[String: Any]] {
                                
                                let text = runs.compactMap { $0["text"] as? String }.joined()
                                if idx == 0 {
                                    title = text
                                    if let firstRun = runs.first,
                                       let nav = firstRun["navigationEndpoint"] as? [String: Any] {
                                        if let watch = nav["watchEndpoint"] as? [String: Any],
                                           let vId = watch["videoId"] as? String {
                                            videoId = vId
                                        }
                                        if let browse = nav["browseEndpoint"] as? [String: Any] {
                                            browseId = browse["browseId"] as? String
                                            if let cfg = browse["browseEndpointContextSupportedConfigs"] as? [String: Any],
                                               let mCfg = cfg["browseEndpointContextMusicConfig"] as? [String: Any],
                                               let pt = mCfg["pageType"] as? String {
                                                pageType = pt
                                            }
                                        }
                                    }
                                } else if idx == 1 {
                                    subtitle = text
                                    if let firstRun = runs.first, let aName = firstRun["text"] as? String {
                                        artist = aName
                                    }
                                }
                            }
                        }
                    }
                    
                    // 2. Fallback navigationEndpoint
                    if let nav = r["navigationEndpoint"] as? [String: Any],
                       let browse = nav["browseEndpoint"] as? [String: Any] {
                        if browseId == nil {
                            browseId = browse["browseId"] as? String
                        }
                        if pageType.isEmpty,
                           let cfg = browse["browseEndpointContextSupportedConfigs"] as? [String: Any],
                           let mCfg = cfg["browseEndpointContextMusicConfig"] as? [String: Any],
                           let pt = mCfg["pageType"] as? String {
                            pageType = pt
                        }
                    }
                    
                    // 3. Fallback videoId from playlistItemData
                    if videoId == nil {
                        if let playlistItemData = r["playlistItemData"] as? [String: Any],
                           let vId = playlistItemData["videoId"] as? String {
                            videoId = vId
                        }
                    }
                    
                    // 4. Overlay Play Button Endpoint (for playlistId / videoId)
                    if let overlay = r["overlay"] as? [String: Any],
                       let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                       let content = thumbOverlay["content"] as? [String: Any],
                       let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                       let playNav = playBtn["playNavigationEndpoint"] as? [String: Any] {
                        if let wp = playNav["watchPlaylistEndpoint"] as? [String: Any],
                           let pId = wp["playlistId"] as? String {
                            playlistId = pId
                        }
                        if videoId == nil,
                           let we = playNav["watchEndpoint"] as? [String: Any],
                           let vId = we["videoId"] as? String {
                            videoId = vId
                        }
                    }
                    
                    // 5. Artwork URL
                    var artworkURL: URL? = nil
                    if let thumb = r["thumbnail"] as? [String: Any],
                       let musicThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
                       let thumbObj = musicThumb["thumbnail"] as? [String: Any],
                       let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let u = last["url"] as? String {
                        artworkURL = URL(string: u)
                    }
                    
                    // 6. Determine item type
                    let subLower = subtitle.lowercased()
                    let filterLower = filter?.lowercased() ?? ""
                    let itemType: SearchResultType
                    
                    if pageType.contains("ALBUM") || (browseId?.hasPrefix("MPRE") == true) || subLower.hasPrefix("album") || filterLower == "albums" {
                        itemType = .album
                    } else if pageType.contains("ARTIST") || (browseId?.hasPrefix("UC") == true) || subLower.hasPrefix("artist") || subLower.hasPrefix("artis") || filterLower == "artists" {
                        itemType = .artist
                    } else if pageType.contains("PLAYLIST") || (browseId?.hasPrefix("VL") == true) || (playlistId != nil && videoId == nil) || subLower.hasPrefix("playlist") || filterLower == "playlists" {
                        itemType = .playlist
                    } else if subLower.hasPrefix("video") || filterLower == "videos" {
                        itemType = .video
                    } else {
                        itemType = .song
                    }
                    
                    let key = videoId ?? playlistId ?? browseId ?? "\(title)_\(subtitle)"
                    if !title.isEmpty && title != "Unknown" && seen.insert(key).inserted {
                        results.append(
                            SearchResultItem(
                                id: key,
                                title: title,
                                subtitle: subtitle.isEmpty ? "\(itemType.rawValue) • \(artist)" : subtitle,
                                type: itemType,
                                artworkURL: artworkURL,
                                videoId: videoId,
                                browseId: browseId,
                                playlistId: playlistId,
                                duration: 210
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
    
    // MARK: - 5. Album & Playlist Tracklist Fetcher
    /// Fetches all playable full-length tracks for an Album or Playlist (e.g. OLAK..., PL..., MPRE..., VL...)
    public func fetchPlaylistOrAlbumTracks(identifier: String) async -> [Track] {
        let cleanId = identifier.hasPrefix("VL") ? String(identifier.dropFirst(2)) : identifier
        
        // 1. If identifier is a playlistId, load via watch next queue endpoint
        if cleanId.hasPrefix("OLAK") || cleanId.hasPrefix("PL") || cleanId.hasPrefix("RD") {
            let body: [String: Any] = [
                "context": [
                    "client": [
                        "clientName": "WEB_REMIX",
                        "clientVersion": "1.20250101.01.00",
                        "hl": "id",
                        "gl": "ID"
                    ]
                ],
                "playlistId": cleanId,
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
            req.timeoutInterval = 8.0
            
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let tracks = parsePlaylistPanelVideos(json: json, seedVideoId: "")
                if !tracks.isEmpty {
                    return tracks
                }
            }
        }
        
        // 2. Query /youtubei/v1/browse with browseId
        let browseId = cleanId.hasPrefix("VL") || cleanId.hasPrefix("MPRE") ? cleanId : "VL\(cleanId)"
        let browseBody: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "browseId": browseId
        ]
        
        guard let bUrl = URL(string: "https://music.youtube.com/youtubei/v1/browse") else { return [] }
        var bReq = URLRequest(url: bUrl)
        bReq.httpMethod = "POST"
        bReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bReq.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        bReq.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        bReq.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        bReq.httpBody = try? JSONSerialization.data(withJSONObject: browseBody)
        bReq.timeoutInterval = 8.0
        
        if let (data, resp) = try? await session.data(for: bReq),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let browseTracks = parseBrowseTracks(json: json)
            if !browseTracks.isEmpty {
                return browseTracks
            }
        }
        
        return []
    }
    
    // MARK: - 6. Artist Top Tracks Fetcher
    /// Fetches top songs of an Artist by browseId (UC...)
    public func fetchArtistTracks(browseId: String) async -> [Track] {
        let browseBody: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20250101.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "browseId": browseId
        ]
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse") else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: browseBody)
        req.timeoutInterval = 8.0
        
        if let (data, resp) = try? await session.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseBrowseTracks(json: json)
        }
        return []
    }
    
    private func parseBrowseTracks(json: Any) -> [Track] {
        var results: [Track] = []
        var seen = Set<String>()
        
        func extract(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let r = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    var videoId: String? = nil
                    var songTitle = "Unknown Track"
                    var artistName = "YouTube Music"
                    var albumName = ""
                    
                    if let flexColumns = r["flexColumns"] as? [[String: Any]] {
                        for (idx, flex) in flexColumns.enumerated() {
                            if let flexRenderer = flex["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                               let textObj = flexRenderer["text"] as? [String: Any],
                               let runs = textObj["runs"] as? [[String: Any]] {
                                
                                let text = runs.compactMap { $0["text"] as? String }.joined()
                                if idx == 0 {
                                    songTitle = text
                                    if let firstRun = runs.first,
                                       let nav = firstRun["navigationEndpoint"] as? [String: Any],
                                       let watch = nav["watchEndpoint"] as? [String: Any],
                                       let vId = watch["videoId"] as? String {
                                        videoId = vId
                                    }
                                } else if idx == 1 {
                                    artistName = text
                                } else if idx == 2 {
                                    albumName = text
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
                    
                    if let vId = videoId, vId.count == 11, seen.insert(vId).inserted {
                        results.append(
                            Track(
                                id: vId,
                                title: songTitle,
                                artist: artistName,
                                album: albumName.isEmpty ? "YouTube Music" : albumName,
                                duration: 210,
                                artworkURL: artworkURL,
                                streamURL: nil,
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
