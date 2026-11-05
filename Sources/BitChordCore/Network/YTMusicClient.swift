import Foundation
import CryptoKit

public actor YTMusicClient {
    public static let shared = YTMusicClient()
    private let session: URLSession
    private var sessionCookies: String? = nil
    
    public func setSessionCookies(_ cookies: String?) {
        self.sessionCookies = cookies
    }
    
    private func applyAuthHeaders(to request: inout URLRequest) {
        guard let cookies = sessionCookies, !cookies.isEmpty else { return }
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        
        let entries = cookies.components(separatedBy: ";")
        for entry in entries {
            let parts = entry.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if (name == "SAPISID" || name == "__Secure-3PAPISID" || name == "__Secure-1PAPISID") && !val.isEmpty {
                let timestamp = Int(Date().timeIntervalSince1970)
                let payload = "\(timestamp) \(val) https://music.youtube.com"
                let hash = Insecure.SHA1.hash(data: Data(payload.utf8))
                let hex = hash.map { String(format: "%02x", $0) }.joined()
                request.setValue("SAPISIDHASH \(timestamp)_\(hex)", forHTTPHeaderField: "Authorization")
                break
            }
        }
    }
    
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
    /// Also supports direct YouTube video URLs (`youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/shorts/...`)
    /// and standard YouTube videos so audio from any YouTube video can be played seamlessly.
    public func searchItems(query: String, filter: String? = nil) async throws -> [SearchResultItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        // 1. If the user pasted a direct YouTube Video URL or 11-char videoId, resolve its metadata and include it at the top
        if let directVideoId = Self.extractYouTubeVideoId(from: trimmedQuery) {
            if let directVideoItem = await fetchVideoSearchItem(videoId: directVideoId) {
                let extra = await searchViaInnertube(query: directVideoItem.title, filter: filter)
                var combined = [directVideoItem]
                for item in extra where item.videoId != directVideoId && item.id != directVideoId {
                    combined.append(item)
                }
                return combined
            }
        }
        
        let filterLower = filter?.lowercased() ?? "all"
        let isVideosOrAll = (filterLower == "videos" || filterLower == "all")
        
        if isVideosOrAll {
            async let ytMusicTask = searchViaInnertube(query: trimmedQuery, filter: filter)
            async let ytStandardVideosTask = searchViaStandardYouTubeVideos(query: trimmedQuery)
            let (ytMusicResults, standardVideos) = await (ytMusicTask, ytStandardVideosTask)
            
            var merged: [SearchResultItem] = []
            var seenKeys = Set<String>()
            
            for item in ytMusicResults {
                let k = item.videoId ?? item.id
                if seenKeys.insert(k).inserted {
                    merged.append(item)
                }
            }
            
            for video in standardVideos {
                let k = video.videoId ?? video.id
                if seenKeys.insert(k).inserted {
                    merged.append(video)
                }
            }
            
            if !merged.isEmpty {
                return merged
            }
        } else {
            let ytMusicResults = await searchViaInnertube(query: trimmedQuery, filter: filter)
            if !ytMusicResults.isEmpty {
                return ytMusicResults
            }
        }
        
        // Fallback to iTunes metadata if needed
        if let itunesResults = await searchViaITunes(query: trimmedQuery), !itunesResults.isEmpty {
            return itunesResults.map { track in
                SearchResultItem(
                    id: track.id,
                    title: track.title,
                    subtitle: "Lagu • \(track.artist)",
                    type: .song,
                    artist: track.artist,
                    album: track.album,
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
                    artist: track.artist,
                    album: track.album,
                    artworkURL: track.artworkURL,
                    videoId: track.id,
                    duration: track.duration
                )
            }
        }
        
        return []
    }
    
    /// Resolves direct YouTube 11-character videoId from track title, artist, album, and duration with strict version matching
    public func resolveYouTubeVideoId(
        title: String,
        artist: String?,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async -> String? {
        let cleanArtist: String
        if let a = artist?.trimmingCharacters(in: .whitespacesAndNewlines),
           !a.isEmpty,
           a.lowercased() != "youtube music",
           !a.lowercased().contains("unknown") {
            cleanArtist = a
        } else {
            cleanArtist = ""
        }
        let query = "\(title) \(cleanArtist)".trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Primary search with Songs filter (prioritizes official studio & exact version tracks)
        if let json = await performInnertubeSearchRequest(query: query, params: "EgWKAQIIAWoKEAkQChAFEAMQBA=="),
           let matchedId = extractBestMatchingSongVideoId(
               from: json,
               requestedTitle: title,
               requestedArtist: cleanArtist,
               requestedAlbum: album,
               requestedDuration: duration
           ) {
            return matchedId
        }
        
        // 2. Secondary general search on YouTube Music (catches explicit Acoustic / Live / Instrumental / Remix / Cover recordings)
        if let json = await performInnertubeSearchRequest(query: query, params: nil),
           let matchedId = extractBestMatchingSongVideoId(
               from: json,
               requestedTitle: title,
               requestedArtist: cleanArtist,
               requestedAlbum: album,
               requestedDuration: duration
           ) {
            return matchedId
        }
        
        // 3. Fallback to another reliable source (Piped / Invidious) with the same strict version verification
        if let pipedTracks = await searchViaPiped(query: query) {
            var bestId: String? = nil
            var bestScore: Double = -1
            for cand in pipedTracks where cand.id.count == 11 {
                if let score = TrackVersionMatcher.matchScore(
                    requestedTitle: title,
                    requestedArtist: cleanArtist,
                    requestedAlbum: album,
                    requestedDuration: duration,
                    candidateTitle: cand.title,
                    candidateArtist: cand.artist,
                    candidateAlbum: cand.album,
                    candidateDuration: cand.duration
                ), score > bestScore {
                    bestScore = score
                    bestId = cand.id
                }
            }
            if let bestId = bestId {
                return bestId
            }
        }
        
        return nil
    }
    
    /// Resolves official YouTube Music Topic / Audio videoId which always has embedding allowed and matches the exact version
    public func resolveTopicVideoId(
        title: String,
        artist: String?,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async -> String? {
        let cleanArtist = artist?.components(separatedBy: " ft.")[0].components(separatedBy: " feat.")[0].trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let query = "\(title) \(cleanArtist)".trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let json = await performInnertubeSearchRequest(query: query, params: "EgWKAQIIAWoKEAkQChAFEAMQBA=="),
           let matchedId = extractBestMatchingSongVideoId(
               from: json,
               requestedTitle: title,
               requestedArtist: artist ?? cleanArtist,
               requestedAlbum: album,
               requestedDuration: duration
           ) {
            return matchedId
        }
        return nil
    }
    
    private func performInnertubeSearchRequest(query: String, params: String?) async -> [String: Any]? {
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
        if let params = params {
            body["params"] = params
        }
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        applyAuthHeaders(to: &req)
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 4.0
        
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
    
    /// Evaluates all shelf items using `TrackVersionMatcher.matchScore` and selects the highest-scoring exact version match.
    /// Never substitutes a Live, Acoustic, Instrumental, Remix, Cover, Karaoke, Sped-Up, or Slowed version for a Studio version (or vice versa).
    private func extractBestMatchingSongVideoId(
        from json: [String: Any],
        requestedTitle: String,
        requestedArtist: String,
        requestedAlbum: String?,
        requestedDuration: TimeInterval?
    ) -> String? {
        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]] else {
            return nil
        }
        
        var bestVideoId: String? = nil
        var bestScore: Double = -1
        
        for tab in tabs {
            guard let tabRenderer = tab["tabRenderer"] as? [String: Any],
                  let tabContent = tabRenderer["content"] as? [String: Any],
                  let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
                  let sections = sectionList["contents"] as? [[String: Any]] else {
                continue
            }
            for section in sections {
                guard let shelf = section["musicShelfRenderer"] as? [String: Any],
                      let items = shelf["contents"] as? [[String: Any]] else {
                    continue
                }
                for (itemIndex, item) in items.enumerated() {
                    guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                    let vId = (renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String
                        ?? extractFirstVideoId(from: renderer)
                    guard let candidateId = vId, candidateId.count == 11, !candidateId.hasPrefix("yt_") else { continue }
                    
                    var candidateTitle = ""
                    var candidateArtist = ""
                    var candidateAlbum: String? = nil
                    var allSubtitleRuns: [String] = []
                    var allTextLower = ""
                    var parsedDuration: Double? = nil
                    
                    if let flexCols = renderer["flexColumns"] as? [[String: Any]] {
                        for (colIndex, col) in flexCols.enumerated() {
                            guard let textRenderer = col["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                                  let textObj = textRenderer["text"] as? [String: Any],
                                  let runs = textObj["runs"] as? [[String: Any]] else { continue }
                            if colIndex == 0 {
                                candidateTitle = runs.compactMap { $0["text"] as? String }.joined()
                                allTextLower += " " + candidateTitle.lowercased()
                            } else {
                                var groups: [[String]] = [[]]
                                for run in runs {
                                    guard let t = run["text"] as? String else { continue }
                                    allTextLower += " " + t.lowercased()
                                    let parts = t.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
                                    if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                                        parsedDuration = m * 60 + s
                                    } else if parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                                        parsedDuration = h * 3600 + m * 60 + s
                                    }
                                    if t.contains("•") {
                                        groups.append([])
                                    } else {
                                        groups[groups.count - 1].append(t)
                                    }
                                }
                                let cleanGroups = groups
                                    .map { $0.joined().trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                allSubtitleRuns.append(contentsOf: cleanGroups)
                                
                                let typeTokens: Set<String> = ["song", "lagu", "video", "album", "single", "ep"]
                                var nonTypeGroups = cleanGroups
                                if let first = nonTypeGroups.first, typeTokens.contains(first.lowercased()) {
                                    nonTypeGroups.removeFirst()
                                }
                                if let firstArtist = nonTypeGroups.first {
                                    candidateArtist = firstArtist
                                }
                                if nonTypeGroups.count > 1 {
                                    let second = nonTypeGroups[1]
                                    let lowerSecond = second.lowercased()
                                    if !lowerSecond.contains("views") && !lowerSecond.contains("ditonton") && !lowerSecond.contains("plays") && second.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) == nil {
                                        candidateAlbum = second
                                    }
                                }
                            }
                        }
                    }
                    
                    if let dur = parsedDuration, dur > 0 && dur < 60 {
                        continue
                    }
                    if allTextLower.contains("teaser") || allTextLower.contains("#shorts") || allTextLower.contains("preview") || allTextLower.contains(" snippet") {
                        continue
                    }
                    
                    let subtitleJoined = allSubtitleRuns.joined(separator: " • ")
                    if let rawScore = TrackVersionMatcher.matchScore(
                        requestedTitle: requestedTitle,
                        requestedArtist: requestedArtist,
                        requestedAlbum: requestedAlbum,
                        requestedDuration: requestedDuration,
                        candidateTitle: candidateTitle,
                        candidateArtist: candidateArtist,
                        candidateAlbum: candidateAlbum,
                        candidateSubtitle: subtitleJoined,
                        candidateDuration: parsedDuration
                    ) {
                        // Slight shelf-order tie-breaker for equally matched official recordings
                        let adjustedScore = rawScore - Double(min(itemIndex, 10)) * 0.25
                        if adjustedScore > bestScore {
                            bestScore = adjustedScore
                            bestVideoId = candidateId
                        }
                    }
                }
            }
        }
        return bestVideoId
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
    
    /// Generates radio / autoplay recommendations of genuinely similar full-length tracks
    /// evaluated across genre/subgenre, country/musical origin, mood, tempo/BPM, energy, popularity, and artist metadata.
    public func fetchRadioTracks(for track: Track, sessionHistoryIds: Set<String>? = nil) async -> [Track] {
        let seedProfile = RadioRecommendationScorer.profile(for: track)
        let cleanArtist = seedProfile.primaryArtist
        
        var historyIds: Set<String> = sessionHistoryIds ?? []
        let activeSessionHistory = await MainActor.run {
            var ids = AudioPlayerEngine.shared.sessionPlayedTrackIds
            for qTrack in AudioPlayerEngine.shared.queue {
                ids.insert(qTrack.id)
            }
            return ids
        }
        historyIds.formUnion(activeSessionHistory)
        historyIds.insert(track.id)
        
        var videoId: String? = nil
        if track.id.count == 11 && !track.id.hasPrefix("yt_") {
            videoId = track.id
        } else if let resolved = await resolveYouTubeVideoId(title: track.title, artist: track.artist, album: track.album, duration: track.duration) {
            videoId = resolved
            historyIds.insert(resolved)
        }
        
        var rawCandidates: [Track] = []
        
        // 1. Official YouTube Music Radio endpoint (RDAMVM)
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
                    rawCandidates.append(contentsOf: radioItems)
                }
            }
        }
        
        // 2. Supplement with subgenre & related-artist candidates if RDAMVM returned few items
        let relatedArtistsMap: [String: [String]] = [
            "muse": ["Radiohead", "The Killers", "Arctic Monkeys", "Placebo", "Franz Ferdinand", "Coldplay", "Oasis"],
            "radiohead": ["Muse", "Coldplay", "The Verve", "Oasis", "Keane", "Travis", "Blur"],
            "arctic monkeys": ["The Strokes", "The Killers", "Franz Ferdinand", "Oasis", "Kasabian", "Muse"],
            "noah": ["Peterpan", "Dewa 19", "Sheila On 7", "Ungu", "D'Masiv", "Samson", "Kerispatih", "Ada Band"],
            "peterpan": ["NOAH", "Dewa 19", "Sheila On 7", "Ungu", "D'Masiv", "Samson", "Padi", "Gigi"],
            "dewa 19": ["Padi", "Sheila On 7", "Gigi", "Slank", "NOAH", "Peterpan", "Ari Lasso", "Ada Band"],
            "sheila on 7": ["Padi", "Dewa 19", "NOAH", "Peterpan", "Gigi", "Ungu", "Jikustik", "Letto"],
            "tulus": ["Hindia", "Pamungkas", "Kunto Aji", "Nadin Amizah", "Raisa", "Sal Priadi", "Fiersa Besari"],
            "hindia": ["Feast", "Pamungkas", "Kunto Aji", "Tulus", "Nadin Amizah", "Payung Teduh", "Efek Rumah Kaca"],
            "linkin park": ["Evanescence", "Papa Roach", "System of a Down", "Green Day", "Three Days Grace", "Breaking Benjamin"],
            "coldplay": ["Keane", "OneRepublic", "The Fray", "Snow Patrol", "Imagine Dragons", "The Script", "Travis"],
            "queen": ["Led Zeppelin", "The Beatles", "Pink Floyd", "Elton John", "David Bowie", "Aerosmith"]
        ]
        
        if rawCandidates.count < 12 {
            var targetQueries: [String] = []
            if let relatedList = relatedArtistsMap[cleanArtist] ?? relatedArtistsMap.first(where: { cleanArtist.contains($0.key) })?.value {
                for rel in relatedList.prefix(4) {
                    targetQueries.append("\(rel) official audio")
                }
            } else if !cleanArtist.isEmpty {
                targetQueries.append("\(cleanArtist) \(seedProfile.subgenre) official audio")
                targetQueries.append("\(cleanArtist) radio")
            } else {
                targetQueries.append("\(track.title) \(seedProfile.subgenre) official audio")
            }
            
            for q in targetQueries {
                if let searchTracks = try? await search(query: q, filter: "EgWKAQIIAWoKEAkQChAFEAMQBA==") {
                    rawCandidates.append(contentsOf: searchTracks.prefix(8))
                }
            }
        }
        
        // 3. Strictly evaluate, rank, deduplicate, and filter candidates via RadioRecommendationScorer
        let curated = RadioRecommendationScorer.rankAndFilterRadioCandidates(
            seed: track,
            candidates: rawCandidates,
            sessionHistoryIds: historyIds,
            maxResults: 20,
            maxPerArtist: 2
        )
        
        return curated
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
                    var albumName = "YouTube Music"
                    if let runs = (r["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]] {
                        var groups: [[String]] = [[]]
                        for run in runs {
                            let t = run["text"] as? String ?? ""
                            if t.contains("•") {
                                groups.append([])
                            } else {
                                groups[groups.count - 1].append(t)
                            }
                        }
                        let groupStrings = groups.map { $0.joined().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        if let first = groupStrings.first, !first.isEmpty {
                            artistName = first
                        }
                        if groupStrings.count > 1 {
                            let candidate = groupStrings[1]
                            let lower = candidate.lowercased()
                            if !lower.contains("views") && !lower.contains("ditonton") && !lower.contains("pemutaran") && candidate.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) == nil {
                                albumName = candidate
                            }
                        }
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
                            album: albumName,
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
        applyAuthHeaders(to: &request)
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
                    var extractedArtist: String? = nil
                    var extractedAlbum: String? = nil
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
                                    
                                    // Parse artist and album directly from run endpoints
                                    var runGroups: [[[String: Any]]] = [[]]
                                    for run in runs {
                                        let t = (run["text"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                                        if t == "•" {
                                            runGroups.append([])
                                        } else {
                                            runGroups[runGroups.count - 1].append(run)
                                        }
                                    }
                                    
                                    for group in runGroups {
                                        for run in group {
                                            if let nav = run["navigationEndpoint"] as? [String: Any],
                                               let browse = nav["browseEndpoint"] as? [String: Any] {
                                                let bId = browse["browseId"] as? String ?? ""
                                                let pType = ((browse["browseEndpointContextSupportedConfigs"] as? [String: Any])?["browseEndpointContextMusicConfig"] as? [String: Any])?["pageType"] as? String ?? ""
                                                
                                                if (pType.contains("ARTIST") || bId.hasPrefix("UC")) && extractedArtist == nil {
                                                    let name = group.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespaces)
                                                    if !name.isEmpty { extractedArtist = name }
                                                } else if (pType.contains("ALBUM") || bId.hasPrefix("MPRE")) && extractedAlbum == nil {
                                                    let aName = group.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespaces)
                                                    if !aName.isEmpty { extractedAlbum = aName }
                                                }
                                            }
                                        }
                                    }
                                    
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
                    } else if pageType.contains("MUSIC_VIDEO_TYPE_OMV") || pageType.contains("MUSIC_VIDEO_TYPE_UGC") || pageType.contains("MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC") || subLower.hasPrefix("video") || subLower.contains("ditonton") || subLower.contains("views") || filterLower == "videos" {
                        itemType = .video
                    } else {
                        itemType = .song
                    }
                    
                    if extractedArtist == nil {
                        extractedArtist = SearchResultItem.extractArtist(from: subtitle, type: itemType)
                    }
                    if extractedAlbum == nil {
                        extractedAlbum = SearchResultItem.extractAlbum(from: subtitle)
                    }
                    
                    let key = videoId ?? playlistId ?? browseId ?? "\(title)_\(subtitle)"
                    if !title.isEmpty && title != "Unknown" && seen.insert(key).inserted {
                        results.append(
                            SearchResultItem(
                                id: key,
                                title: title,
                                subtitle: subtitle.isEmpty ? "\(itemType.rawValue) • \(extractedArtist ?? artist)" : subtitle,
                                type: itemType,
                                artist: extractedArtist,
                                album: extractedAlbum,
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
    
    // MARK: - 4b. Standard YouTube Video Search & URL Resolver (Play Audio from Any YouTube Video)
    /// Extracts an 11-character YouTube videoId from a pasted URL (`youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/shorts/...`, `music.youtube.com/watch?v=...`)
    public static func extractYouTubeVideoId(from rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("youtube.com/") || trimmed.contains("youtu.be/") else {
            return nil
        }
        
        if let url = URL(string: trimmed) {
            if let host = url.host?.lowercased(), host.contains("youtu.be") {
                let pathId = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if pathId.count == 11 {
                    return pathId
                }
            }
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let vParam = comps.queryItems?.first(where: { $0.name == "v" })?.value,
               vParam.count == 11 {
                return vParam
            }
            let parts = url.pathComponents
            if let shortsIdx = parts.firstIndex(of: "shorts"), shortsIdx + 1 < parts.count {
                let candidate = parts[shortsIdx + 1]
                if candidate.count == 11 { return candidate }
            }
            if let liveIdx = parts.firstIndex(of: "live"), liveIdx + 1 < parts.count {
                let candidate = parts[liveIdx + 1]
                if candidate.count == 11 { return candidate }
            }
        }
        
        if let range = trimmed.range(of: #"(?:v=|youtu\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})"#, options: .regularExpression) {
            let match = String(trimmed[range])
            let idPart = String(match.suffix(11))
            if idPart.count == 11 {
                return idPart
            }
        }
        return nil
    }
    
    /// Resolves metadata for a specific 11-character YouTube video ID so its audio can be played directly.
    public func fetchVideoSearchItem(videoId: String) async -> SearchResultItem? {
        guard videoId.count == 11,
              let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return nil }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "20.10.4",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone",
                    "osVersion": "18.3.2.22D82",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 5.0
        
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let details = json["videoDetails"] as? [String: Any] else {
            return SearchResultItem(
                id: videoId,
                title: "YouTube Video (\(videoId))",
                subtitle: "Video • YouTube",
                type: .video,
                artist: "YouTube",
                album: "YouTube Video",
                artworkURL: URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"),
                videoId: videoId,
                duration: 210,
                source: .youtube
            )
        }
        
        let title = details["title"] as? String ?? "YouTube Video"
        let author = (details["author"] as? String ?? "YouTube").replacingOccurrences(of: " - Topic", with: "")
        let lengthSec = Double(details["lengthSeconds"] as? String ?? "210") ?? 210
        let artworkURL = URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
        
        return SearchResultItem(
            id: videoId,
            title: title,
            subtitle: "Video • \(author)",
            type: .video,
            artist: author,
            album: "YouTube Video",
            artworkURL: artworkURL,
            videoId: videoId,
            duration: lengthSec > 0 ? lengthSec : 210,
            source: .youtube
        )
    }
    
    /// Queries standard YouTube (`www.youtube.com/youtubei/v1/search`) so any YouTube video (official MV, live session, acoustic cover, podcast, etc.)
    /// can be discovered and its audio played directly in BitChord.
    private func searchViaStandardYouTubeVideos(query: String) async -> [SearchResultItem] {
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20250101.00.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "query": query
        ]
        
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 6.0
        
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var videos: [SearchResultItem] = []
        var seen = Set<String>()
        
        func extractVideos(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let vr = dict["videoRenderer"] as? [String: Any],
                   let vId = vr["videoId"] as? String, vId.count == 11 {
                    let titleRuns = (vr["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let title = titleRuns?.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    let ownerRuns = ((vr["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]])
                        ?? ((vr["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]])
                    let channelName = (ownerRuns?.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? "YouTube")
                        .replacingOccurrences(of: " - Topic", with: "")
                    
                    var duration: TimeInterval = 210
                    var durationLabel = ""
                    if let lengthText = (vr["lengthText"] as? [String: Any])?["simpleText"] as? String {
                        durationLabel = lengthText
                        let parts = lengthText.replacingOccurrences(of: ".", with: ":").split(separator: ":")
                        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                            duration = m * 60 + s
                        } else if parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                            duration = h * 3600 + m * 60 + s
                        }
                    }
                    
                    // Skip YouTube Shorts (< 45s) unless explicitly searched
                    if duration > 0 && duration < 45 && !query.lowercased().contains("short") {
                        return
                    }
                    
                    var artworkURL = URL(string: "https://i.ytimg.com/vi/\(vId)/hqdefault.jpg")
                    if let thumbObj = vr["thumbnail"] as? [String: Any],
                       let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let u = last["url"] as? String,
                       let parsedURL = URL(string: u) {
                        artworkURL = parsedURL
                    }
                    
                    let sub = durationLabel.isEmpty ? "Video • \(channelName)" : "Video • \(channelName) • \(durationLabel)"
                    if !title.isEmpty && seen.insert(vId).inserted {
                        videos.append(
                            SearchResultItem(
                                id: vId,
                                title: title,
                                subtitle: sub,
                                type: .video,
                                artist: channelName,
                                album: "YouTube Video",
                                artworkURL: artworkURL,
                                videoId: vId,
                                duration: duration,
                                source: .youtube
                            )
                        )
                    }
                }
                for (_, val) in dict {
                    extractVideos(from: val)
                }
            } else if let arr = obj as? [Any] {
                for it in arr {
                    extractVideos(from: it)
                }
            }
        }
        
        extractVideos(from: json)
        return videos
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
        
        // Extract album/playlist header metadata
        var headerArtist: String? = nil
        var headerAlbum: String? = nil
        var headerArtworkURL: URL? = nil
        
        func extractHeader(from obj: Any) {
            guard headerArtist == nil || headerAlbum == nil || headerArtworkURL == nil else { return }
            if let dict = obj as? [String: Any] {
                if let header = dict["musicResponsiveHeaderRenderer"] as? [String: Any] {
                    if let strapline = header["straplineTextOne"] as? [String: Any],
                       let runs = strapline["runs"] as? [[String: Any]] {
                        let name = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { headerArtist = name }
                    }
                    if let titleObj = header["title"] as? [String: Any],
                       let runs = titleObj["runs"] as? [[String: Any]] {
                        let aName = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !aName.isEmpty { headerAlbum = aName }
                    }
                    if let thumb = header["thumbnail"] as? [String: Any],
                       let mThumb = thumb["musicThumbnailRenderer"] as? [String: Any],
                       let tObj = mThumb["thumbnail"] as? [String: Any],
                       let thumbs = tObj["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last,
                       let u = last["url"] as? String {
                        headerArtworkURL = URL(string: u)
                    }
                } else if let detail = dict["musicDetailHeaderRenderer"] as? [String: Any] {
                    if let subObj = detail["subtitle"] as? [String: Any],
                       let runs = subObj["runs"] as? [[String: Any]] {
                        for run in runs {
                            if let nav = run["navigationEndpoint"] as? [String: Any],
                               let browse = nav["browseEndpoint"] as? [String: Any] {
                                let bId = browse["browseId"] as? String ?? ""
                                if bId.hasPrefix("UC") {
                                    headerArtist = run["text"] as? String
                                }
                            }
                        }
                    }
                    if let titleObj = detail["title"] as? [String: Any],
                       let runs = titleObj["runs"] as? [[String: Any]] {
                        let aName = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !aName.isEmpty { headerAlbum = aName }
                    }
                }
                for (_, v) in dict {
                    extractHeader(from: v)
                }
            } else if let arr = obj as? [Any] {
                for it in arr {
                    extractHeader(from: it)
                }
            }
        }
        
        extractHeader(from: json)
        
        func extract(from obj: Any) {
            if let dict = obj as? [String: Any] {
                if let r = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    var videoId: String? = nil
                    var songTitle = "Unknown Track"
                    var trackArtist: String? = nil
                    var trackAlbum: String? = nil
                    
                    if let flexColumns = r["flexColumns"] as? [[String: Any]] {
                        for (idx, flex) in flexColumns.enumerated() {
                            if let flexRenderer = flex["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                               let textObj = flexRenderer["text"] as? [String: Any],
                               let runs = textObj["runs"] as? [[String: Any]] {
                                
                                let text = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                                if idx == 0 {
                                    songTitle = text
                                    if let firstRun = runs.first,
                                       let nav = firstRun["navigationEndpoint"] as? [String: Any],
                                       let watch = nav["watchEndpoint"] as? [String: Any],
                                       let vId = watch["videoId"] as? String {
                                        videoId = vId
                                    }
                                } else if idx == 1 && !text.isEmpty {
                                    for run in runs {
                                        if let nav = run["navigationEndpoint"] as? [String: Any],
                                           let browse = nav["browseEndpoint"] as? [String: Any] {
                                            let bId = browse["browseId"] as? String ?? ""
                                            if bId.hasPrefix("UC") {
                                                trackArtist = run["text"] as? String
                                            }
                                        }
                                    }
                                    if trackArtist == nil && !text.contains("pemutaran") && !text.contains("ditonton") && text.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) == nil {
                                        trackArtist = text
                                    }
                                } else if idx == 2 && !text.isEmpty {
                                    if !text.contains("pemutaran") && !text.contains("ditonton") && text.range(of: #"^\d+[\.:]\d+$"#, options: .regularExpression) == nil {
                                        trackAlbum = text
                                    }
                                }
                            }
                        }
                    }
                    
                    // Accessibility data fallback on play button (e.g. "Putar Manusia Bodoh - Ada Band" or "Play Song by Artist")
                    if trackArtist == nil,
                       let overlay = r["overlay"] as? [String: Any],
                       let mOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                       let content = mOverlay["content"] as? [String: Any],
                       let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
                       let aData = playBtn["accessibilityPlayData"] as? [String: Any],
                       let aInner = aData["accessibilityData"] as? [String: Any],
                       let label = aInner["label"] as? String {
                        if let dashIdx = label.range(of: " - ") {
                            trackArtist = String(label[dashIdx.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if let byIdx = label.range(of: " by ") {
                            trackArtist = String(label[byIdx.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
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
                    
                    let finalArtist = trackArtist ?? headerArtist ?? "YouTube Music"
                    let finalAlbum = trackAlbum ?? headerAlbum ?? "YouTube Music"
                    let finalArtwork = artworkURL ?? headerArtworkURL
                    
                    if let vId = videoId, vId.count == 11, seen.insert(vId).inserted {
                        results.append(
                            Track(
                                id: vId,
                                title: songTitle,
                                artist: finalArtist,
                                album: finalAlbum,
                                duration: 210,
                                artworkURL: finalArtwork,
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
    
    // MARK: - 7. Song Info Fetcher
    public func fetchSongInfo(for track: Track) async -> SongInfo {
        let cleanAlbum = track.album.isEmpty || track.album == "YouTube Music" ? "-" : track.album
        let vId = track.id
        guard vId.count == 11 && !vId.hasPrefix("yt_") else {
            return SongInfo(album: cleanAlbum)
        }
        
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player") else {
            return SongInfo(album: cleanAlbum)
        }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240401.01.00",
                    "hl": "id",
                    "gl": "ID"
                ]
            ],
            "videoId": vId
        ]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 5.0
        
        var viewsString = "-"
        var releaseDateString = "-"
        
        if let (data, resp) = try? await session.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let details = json["videoDetails"] as? [String: Any],
               let viewCount = details["viewCount"] as? String {
                viewsString = formatCompactCount(viewCount)
            }
            
            if let micro = json["microformat"] as? [String: Any],
               let r = micro["microformatDataRenderer"] as? [String: Any] {
                if let pDate = r["publishDate"] as? String {
                    releaseDateString = formatReleaseDate(pDate)
                } else if let uDate = r["uploadDate"] as? String {
                    releaseDateString = formatReleaseDate(uDate)
                }
            }
        }
        
        return SongInfo(
            album: cleanAlbum,
            releaseDate: releaseDateString,
            views: viewsString,
            likes: "-",
            comments: "-"
        )
    }
    
    private func formatCompactCount(_ raw: String) -> String {
        guard let n = Double(raw), n >= 0 else { return raw }
        if n >= 1_000_000_000 {
            return String(format: "%.1fB", n / 1_000_000_000).replacingOccurrences(of: ".0", with: "")
        } else if n >= 1_000_000 {
            return String(format: "%.1fM", n / 1_000_000).replacingOccurrences(of: ".0", with: "")
        } else if n >= 1_000 {
            return String(format: "%.1fK", n / 1_000).replacingOccurrences(of: ".0", with: "")
        } else {
            return "\(Int(n))"
        }
    }
    
    private func formatReleaseDate(_ raw: String) -> String {
        let prefix = String(raw.prefix(10))
        let parts = prefix.split(separator: "-")
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            if m >= 1 && m <= 12 {
                return "\(d) \(months[m - 1]) \(y)"
            }
        }
        return raw.count >= 4 ? String(raw.prefix(4)) : raw
    }
}
