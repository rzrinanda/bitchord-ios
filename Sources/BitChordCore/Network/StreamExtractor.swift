import Foundation

public struct StreamInfo: Sendable, Equatable {
    public let streamURL: URL
    public let format: String
    public let codec: String
    public let bitrate: Int
    public let isLossless: Bool
    public let sampleRate: Double?
    public let bitDepth: Int?
    public let sourceId: String
    public let sourceIsDirect: Bool
    
    public init(
        streamURL: URL,
        format: String = "audio/mp4",
        codec: String? = nil,
        bitrate: Int = 256,
        isLossless: Bool = false,
        sampleRate: Double? = 44100,
        bitDepth: Int? = nil,
        sourceId: String = "yt_innertube_ios",
        sourceIsDirect: Bool = true
    ) {
        self.streamURL = streamURL
        self.format = format
        let inferredCodec = Self.detectCodec(from: format, explicitCodec: codec)
        self.codec = inferredCodec
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        let genuineLossless = Self.evaluateGenuineLossless(format: format, codec: inferredCodec, claimedLossless: isLossless)
        self.isLossless = genuineLossless
        self.bitDepth = genuineLossless ? (bitDepth ?? ((sampleRate ?? 44100) > 48000 ? 24 : 16)) : nil
        self.sourceId = sourceId
        self.sourceIsDirect = sourceIsDirect
    }
    
    /// Verifies that lossless claims are backed by actual lossless codec/container metadata (FLAC, ALAC, WAV, PCM).
    /// Never trusts a boolean label alone if the underlying format/codec is lossy (AAC, Opus, MP3, Vorbis).
    public var isGenuineLossless: Bool {
        Self.evaluateGenuineLossless(format: format, codec: codec, claimedLossless: isLossless)
    }
    
    public static func detectCodec(from format: String, explicitCodec: String? = nil) -> String {
        if let exp = explicitCodec?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty {
            return exp
        }
        let lower = format.lowercased()
        if lower.contains("flac") { return "flac" }
        if lower.contains("alac") || lower.contains("apple lossless") { return "alac" }
        if lower.contains("wav") || lower.contains("pcm") || lower.contains("l16") || lower.contains("l24") { return "pcm" }
        if lower.contains("opus") { return "opus" }
        if lower.contains("vorbis") { return "vorbis" }
        if lower.contains("mp4a") || lower.contains("aac") || lower.contains("audio/mp4") || lower.contains("m4a") { return "aac" }
        if lower.contains("mpeg") || lower.contains("mp3") { return "mp3" }
        if lower.contains("webm") { return "opus" }
        return "aac"
    }
    
    public static func evaluateGenuineLossless(format: String, codec: String, claimedLossless: Bool) -> Bool {
        let lowerFormat = format.lowercased()
        let lowerCodec = codec.lowercased()
        
        // Explicitly reject known lossy formats/codecs regardless of label
        let lossyIndicators = ["opus", "vorbis", "mp3", "audio/mpeg", "mp4a.40", "aac", "audio/webm", "video/mp4", "application/x-mpegurl"]
        for indicator in lossyIndicators {
            if lowerFormat.contains(indicator) || lowerCodec == indicator {
                if !lowerFormat.contains("alac") && !lowerFormat.contains("flac") && lowerCodec != "alac" && lowerCodec != "flac" {
                    return false
                }
            }
        }
        
        let losslessIndicators = ["flac", "alac", "wav", "pcm", "aiff", "apple lossless"]
        for indicator in losslessIndicators {
            if lowerFormat.contains(indicator) || lowerCodec.contains(indicator) {
                return true
            }
        }
        return false
    }
    
    /// Evaluates objective audio quality across format/codec, bitrate, sample rate, bit depth, and source integrity.
    public var qualityScore: Double {
        var score: Double = 0
        let sr = sampleRate ?? 44100
        
        if isGenuineLossless {
            // 1. Genuine lossless formats (FLAC / ALAC / PCM) outrank all lossy streams
            score += 1000.0
            if codec == "flac" || codec == "alac" {
                score += 40.0
            } else if codec == "pcm" {
                score += 35.0
            }
            // 4. Bit depth for lossless PCM audio (24-bit > 16-bit)
            let depth = bitDepth ?? 16
            if depth >= 24 {
                score += 120.0
            } else if depth >= 16 {
                score += 60.0
            }
            // 3. Sample rate (96kHz / 88.2kHz / 48kHz / 44.1kHz)
            if sr >= 96000 {
                score += 90.0
            } else if sr >= 88200 {
                score += 80.0
            } else if sr >= 48000 {
                score += 50.0
            } else if sr >= 44100 {
                score += 30.0
            }
            score += min(60.0, Double(max(0, bitrate)) / 100.0)
        } else {
            // 2. Lossy formats: compare codec perceptual efficiency + bitrate appropriately
            let perceptualEquivalentBitrate: Double
            switch codec {
            case "opus":
                // Opus is perceptually more efficient at lower nominal bitrates than MP3,
                // while 320 kbps AAC/MP3 or 256 kbps AAC still scale cleanly
                perceptualEquivalentBitrate = Double(bitrate) * 1.18
            case "aac":
                perceptualEquivalentBitrate = Double(bitrate) * 1.10
            case "vorbis":
                perceptualEquivalentBitrate = Double(bitrate) * 1.05
            case "mp3":
                perceptualEquivalentBitrate = Double(bitrate) * 1.00
            default:
                perceptualEquivalentBitrate = Double(bitrate) * 0.95
            }
            score += min(600.0, perceptualEquivalentBitrate)
            
            // Explicit tier bonus for standard high bitrates within lossy
            if bitrate >= 320 {
                score += 80.0
            } else if bitrate >= 256 {
                score += 60.0
            } else if bitrate >= 192 {
                score += 40.0
            } else if bitrate >= 128 {
                score += 20.0
            }
            
            if sr >= 48000 {
                score += 15.0
            } else if sr >= 44100 {
                score += 10.0
            }
        }
        
        // 5. Source integrity: prefer original direct sources over re-encoded or proxied streams
        if sourceIsDirect {
            score += 25.0
        }
        return score
    }
    
    /// Normalized quality tier bucket key so each source selects up to 3 distinct quality levels.
    public var qualityTierKey: String {
        if isGenuineLossless {
            let depth = bitDepth ?? 16
            let sr = Int((sampleRate ?? 44100) / 1000)
            return depth >= 24 || sr > 48 ? "lossless_hires_\(depth)bit_\(sr)k" : "lossless_cd_16bit"
        }
        if bitrate >= 280 { return "lossy_320" }
        if bitrate >= 220 { return "lossy_256" }
        if bitrate >= 150 { return "lossy_192" }
        if bitrate >= 100 { return "lossy_128" }
        return "lossy_low"
    }
    
    /// Returns true if the stream format/codec is natively decodable by iOS AVFoundation (`AVPlayer`).
    public var isIOSAVPlayerCompatible: Bool {
        let lowerFormat = format.lowercased()
        let lowerCodec = codec.lowercased()
        if lowerFormat.contains("webm") || lowerFormat.contains("vorbis") || lowerCodec == "vorbis" {
            return false
        }
        if lowerCodec == "opus" && !lowerFormat.contains("mp4") && !lowerFormat.contains("caf") {
            return false
        }
        return true
    }
    
    /// Sorts candidate streams from highest to lowest objective quality and deduplicates into at most `maxLevels` distinct quality tiers.
    public static func selectTopDistinctQualityLevels(from streams: [StreamInfo], maxLevels: Int = 3) -> [StreamInfo] {
        let sorted = streams.sorted { a, b in
            if a.isIOSAVPlayerCompatible != b.isIOSAVPlayerCompatible {
                return a.isIOSAVPlayerCompatible && !b.isIOSAVPlayerCompatible
            }
            if abs(a.qualityScore - b.qualityScore) > 0.01 {
                return a.qualityScore > b.qualityScore
            }
            return a.bitrate > b.bitrate
        }
        var selected: [StreamInfo] = []
        var seenTierKeys: Set<String> = []
        var seenURLs: Set<String> = []
        for stream in sorted {
            let urlKey = stream.streamURL.absoluteString
            guard !seenURLs.contains(urlKey) else { continue }
            guard !seenTierKeys.contains(stream.qualityTierKey) else { continue }
            seenURLs.insert(urlKey)
            seenTierKeys.insert(stream.qualityTierKey)
            selected.append(stream)
            if selected.count >= maxLevels {
                break
            }
        }
        return selected
    }
}

public actor StreamExtractor {
    public static let shared = StreamExtractor()
    
    // YouTube Innertube public client key
    private let innertubeKey = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    
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
    
    public init() {}
    
    private var streamCache: [String: [[StreamInfo]]] = [:]
    private var videoIdCache: [String: String] = [:]
    
    /// Prefetches video ID and ranked stream candidates for a track in the background so Next/Previous playback is instantaneous.
    public func prefetch(
        trackId: String,
        title: String,
        artist: String?,
        album: String?,
        duration: TimeInterval?,
        preferredQuality: AudioQuality = .high
    ) async {
        _ = await extractRankedStreamCandidates(
            trackId: trackId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            preferredQuality: preferredQuality
        )
    }
    
    /// Resolves direct audio stream URL for a track/video ID with multi-source fallback
    public func extractAudioStream(
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        preferredQuality: AudioQuality = .high
    ) async throws -> StreamInfo {
        let grouped = await extractRankedStreamCandidates(
            trackId: trackId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            preferredQuality: preferredQuality
        )
        if let bestSource = grouped.first, let bestStream = bestSource.first {
            return bestStream
        }
        throw URLError(.cannotFindHost)
    }
    
    /// Resolves ranked stream candidates grouped by audio source:
    /// - At most 3 sources total (primary source + up to 2 alternative sources) for the exact same recording and version.
    /// - At most 3 distinct quality levels per source, sorted from highest objective quality to lowest.
    public func extractRankedStreamCandidates(
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        preferredQuality: AudioQuality = .high
    ) async -> [[StreamInfo]] {
        let cacheKey = "\(trackId)|\(title ?? "")|\(artist ?? "")"
        if let cached = streamCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        var effectiveVideoId = trackId
        
        // If trackId is an alias or placeholder, resolve real YouTube 11-char videoId for the exact requested version first
        if effectiveVideoId.count != 11 || effectiveVideoId.hasPrefix("yt_") {
            if let cachedVId = videoIdCache[cacheKey] {
                effectiveVideoId = cachedVId
            } else if let title = title, let resolvedId = await resolveYouTubeVideoId(title: title, artist: artist, album: album, duration: duration) {
                effectiveVideoId = resolvedId
                videoIdCache[cacheKey] = resolvedId
            }
        }
        
        if let cachedByVId = streamCache[effectiveVideoId], !cachedByVId.isEmpty {
            streamCache[cacheKey] = cachedByVId
            return cachedByVId
        }
        
        var sourceGroups: [[StreamInfo]] = []
        let maxSources = 3 // Primary source + maximum 2 alternative sources
        let maxQualityLevelsPerSource = 3
        
        // Source 0: BitChord High-Speed Backend Server (if enabled and reachable)
        let backendConfig = await MainActor.run {
            (
                enabled: BitChordSettings.shared.useBackendServer,
                url: BitChordSettings.shared.backendServerURL,
                isReachable: BitChordSettings.shared.isBackendServerReachable
            )
        }
        if backendConfig.enabled && effectiveVideoId.count == 11 {
            let cleanBase = backendConfig.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = cleanBase.hasSuffix("/") ? String(cleanBase.dropLast()) : cleanBase
            if let backendStreamURL = URL(string: "\(base)/stream/\(effectiveVideoId)") {
                let backendStream = StreamInfo(
                    streamURL: backendStreamURL,
                    format: "audio/mp4",
                    codec: "aac",
                    bitrate: 256,
                    isLossless: false,
                    sampleRate: 44100,
                    sourceId: "bitchord_backend_server",
                    sourceIsDirect: true
                )
                if backendConfig.isReachable {
                    sourceGroups.append([backendStream])
                }
            }
        }
        
        // Source 1: Custom Addon Stream (e.g. SoundFean Qobuz Hi-Res FLAC) for exact matching version
        let activeAddons = await MainActor.run {
            BitChordSettings.shared.addonSources.filter { $0.isEnabled && $0.resources.contains("stream") }
        }
        if let title = title {
            for addon in activeAddons {
                if sourceGroups.count >= maxSources { break }
                let addonTiers = await AddonService.shared.resolveStreamTiers(
                    trackTitle: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    addon: addon
                )
                let ranked = StreamInfo.selectTopDistinctQualityLevels(from: addonTiers, maxLevels: maxQualityLevelsPerSource)
                if !ranked.isEmpty {
                    sourceGroups.append(ranked)
                }
            }
        }
        
        // Fast concurrent extraction across primary & fallback YouTube sources (~200ms)
        if sourceGroups.count < maxSources, effectiveVideoId.count == 11 {
            let vId = effectiveVideoId
            async let iosTask = extractTiersViaYouTubeInnertube(trackId: vId)
            async let androidTask = extractTiersViaYouTubeAndroid(trackId: vId)
            
            let (iosStreams, androidStreams) = await (iosTask, androidTask)
            let rankedIOS = StreamInfo.selectTopDistinctQualityLevels(from: iosStreams, maxLevels: maxQualityLevelsPerSource)
            if !rankedIOS.isEmpty && sourceGroups.count < maxSources {
                sourceGroups.append(rankedIOS)
            }
            
            let rankedAndroid = StreamInfo.selectTopDistinctQualityLevels(from: androidStreams, maxLevels: maxQualityLevelsPerSource)
            if !rankedAndroid.isEmpty && sourceGroups.count < maxSources {
                sourceGroups.append(rankedAndroid)
            }
            
            // Only query third-party proxies (Piped / Invidious) when both Innertube sources returned empty
            if sourceGroups.isEmpty {
                async let pipedTask = extractTiersViaPiped(trackId: vId)
                async let invidiousTask = extractTiersViaInvidious(trackId: vId)
                let (pipedStreams, invidiousStreams) = await (pipedTask, invidiousTask)
                
                let rankedPiped = StreamInfo.selectTopDistinctQualityLevels(from: pipedStreams, maxLevels: maxQualityLevelsPerSource)
                if !rankedPiped.isEmpty && sourceGroups.count < maxSources {
                    sourceGroups.append(rankedPiped)
                }
                let rankedInvidious = StreamInfo.selectTopDistinctQualityLevels(from: invidiousStreams, maxLevels: maxQualityLevelsPerSource)
                if !rankedInvidious.isEmpty && sourceGroups.count < maxSources {
                    sourceGroups.append(rankedInvidious)
                }
            }
        }
        
        let finalGroups = Array(sourceGroups.prefix(maxSources))
        if !finalGroups.isEmpty {
            streamCache[cacheKey] = finalGroups
            if effectiveVideoId.count == 11 {
                streamCache[effectiveVideoId] = finalGroups
            }
        }
        return finalGroups
    }
    
    // Resolve YouTube 11-char Video ID from search (Strict version matching + full-length official audio only)
    private func resolveYouTubeVideoId(
        title: String,
        artist: String?,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async -> String? {
        if let ytMusicId = await YTMusicClient.shared.resolveYouTubeVideoId(title: title, artist: artist, album: album, duration: duration) {
            return ytMusicId
        }
        
        let requestedVersion = TrackVersionMatcher.detectVersion(title: title, album: album)
        let versionHint = requestedVersion == .studio ? "Official Audio" : requestedVersion.rawValue
        let query = "\(title) \(artist ?? "") \(versionHint)".trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "20.10.4",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone",
                    "osVersion": "18.3.2.22D82",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 3.0
        
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var bestVideoId: String? = nil
        var bestScore: Double = -1
        
        if let contents = json["contents"] as? [String: Any],
           let sectionList = contents["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            for section in sections {
                if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                   let contentsArray = itemSection["contents"] as? [[String: Any]] {
                    for item in contentsArray {
                        if let videoRenderer = item["videoRenderer"] as? [String: Any],
                           let vId = videoRenderer["videoId"] as? String, vId.count == 11 {
                            var candidateDuration: TimeInterval? = nil
                            if let lengthText = (videoRenderer["lengthText"] as? [String: Any])?["simpleText"] as? String {
                                let parts = lengthText.split(separator: ":")
                                if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                                    candidateDuration = m * 60 + s
                                } else if parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                                    candidateDuration = h * 3600 + m * 60 + s
                                }
                            }
                            if let dur = candidateDuration, dur > 0 && dur < 60 {
                                continue
                            }
                            let candidateTitle = ((videoRenderer["title"] as? [String: Any])?["runs"] as? [[String: Any]])?.first?["text"] as? String ?? ""
                            let candidateChannel = ((videoRenderer["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]])?.first?["text"] as? String
                                ?? ((videoRenderer["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]])?.first?["text"] as? String
                                ?? ""
                            
                            if let score = TrackVersionMatcher.matchScore(
                                requestedTitle: title,
                                requestedArtist: artist ?? "",
                                requestedAlbum: album,
                                requestedDuration: duration,
                                candidateTitle: candidateTitle,
                                candidateArtist: candidateChannel,
                                candidateAlbum: nil,
                                candidateSubtitle: candidateChannel,
                                candidateDuration: candidateDuration
                            ) {
                                if score > bestScore {
                                    bestScore = score
                                    bestVideoId = vId
                                }
                            }
                        }
                    }
                }
            }
        }
        return bestVideoId
    }
    
    // MARK: - 1. Direct YouTube Innertube (iOS Client with Public Key)
    private func extractViaYouTubeInnertube(trackId: String) async -> StreamInfo? {
        return await extractTiersViaYouTubeInnertube(trackId: trackId).first
    }
    
    private func extractTiersViaYouTubeInnertube(trackId: String) async -> [StreamInfo] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return [] }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "20.10.4",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone",
                    "osVersion": "18.3.2.22D82",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": trackId,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")
        request.setValue("5", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("20.10.4", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 3.5
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return []
        }
        
        // Reject short clips / teasers (< 60s)
        if let videoDetails = json["videoDetails"] as? [String: Any],
           let lengthStr = videoDetails["lengthSeconds"] as? String,
           let lengthSec = Int(lengthStr), lengthSec > 0 && lengthSec < 60 {
            return []
        }
        
        var candidates: [StreamInfo] = []
        
        // Parse adaptiveFormats
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            for fmt in adaptiveFormats {
                let mime = fmt["mimeType"] as? String ?? ""
                guard mime.contains("audio"),
                      let urlString = fmt["url"] as? String,
                      let streamURL = URL(string: urlString) else { continue }
                let rawBitrate = fmt["bitrate"] as? Int ?? fmt["averageBitrate"] as? Int ?? 128000
                let bitrate = max(32, rawBitrate / 1000)
                let sampleRate = Double(fmt["audioSampleRate"] as? String ?? "44100") ?? 44100
                candidates.append(
                    StreamInfo(
                        streamURL: streamURL,
                        format: mime,
                        bitrate: bitrate,
                        isLossless: false,
                        sampleRate: sampleRate,
                        sourceId: "yt_innertube_ios",
                        sourceIsDirect: true
                    )
                )
            }
        }
        
        // Check HLS manifest
        if let hlsManifest = streamingData["hlsManifestUrl"] as? String,
           let hlsURL = URL(string: hlsManifest) {
            candidates.append(
                StreamInfo(
                    streamURL: hlsURL,
                    format: "application/x-mpegURL",
                    codec: "aac",
                    bitrate: 256,
                    isLossless: false,
                    sampleRate: 44100,
                    sourceId: "yt_innertube_ios",
                    sourceIsDirect: true
                )
            )
        }
        
        // Fallback to combined formats
        if let formats = streamingData["formats"] as? [[String: Any]] {
            for fmt in formats {
                guard let urlString = fmt["url"] as? String,
                      let streamURL = URL(string: urlString) else { continue }
                let rawBitrate = fmt["bitrate"] as? Int ?? 128000
                let bitrate = max(64, min(192, rawBitrate / 1000))
                candidates.append(
                    StreamInfo(
                        streamURL: streamURL,
                        format: "video/mp4",
                        codec: "aac",
                        bitrate: bitrate,
                        isLossless: false,
                        sampleRate: 44100,
                        sourceId: "yt_innertube_ios",
                        sourceIsDirect: true
                    )
                )
            }
        }
        
        return StreamInfo.selectTopDistinctQualityLevels(from: candidates, maxLevels: 3)
    }
    
    // MARK: - 1b. Direct YouTube Innertube (Android Client - Full Length Audio)
    private func extractViaYouTubeAndroid(trackId: String) async -> StreamInfo? {
        return await extractTiersViaYouTubeAndroid(trackId: trackId).first
    }
    
    private func extractTiersViaYouTubeAndroid(trackId: String) async -> [StreamInfo] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return [] }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": "20.10.35",
                    "androidSdkVersion": 34,
                    "osName": "Android",
                    "osVersion": "14",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": trackId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.android.youtube/20.10.35 (Linux; U; Android 14) gzip", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 3.5
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return []
        }
        
        // Reject short clips / teasers (< 60s)
        if let videoDetails = json["videoDetails"] as? [String: Any],
           let lengthStr = videoDetails["lengthSeconds"] as? String,
           let lengthSec = Int(lengthStr), lengthSec > 0 && lengthSec < 60 {
            return []
        }
        
        var candidates: [StreamInfo] = []
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            for fmt in adaptiveFormats {
                let mime = fmt["mimeType"] as? String ?? ""
                guard mime.contains("audio"),
                      let urlString = fmt["url"] as? String,
                      let streamURL = URL(string: urlString) else { continue }
                let rawBitrate = fmt["bitrate"] as? Int ?? fmt["averageBitrate"] as? Int ?? 128000
                let bitrate = max(32, rawBitrate / 1000)
                let sampleRate = Double(fmt["audioSampleRate"] as? String ?? "44100") ?? 44100
                candidates.append(
                    StreamInfo(
                        streamURL: streamURL,
                        format: mime.isEmpty ? "audio/mp4" : mime,
                        bitrate: bitrate,
                        isLossless: false,
                        sampleRate: sampleRate,
                        sourceId: "yt_innertube_android",
                        sourceIsDirect: true
                    )
                )
            }
        }
        return StreamInfo.selectTopDistinctQualityLevels(from: candidates, maxLevels: 3)
    }
    
    // MARK: - 2. Piped Streams
    private func extractViaPiped(trackId: String, preferredQuality: AudioQuality) async -> StreamInfo? {
        return await extractTiersViaPiped(trackId: trackId).first
    }
    
    private func extractTiersViaPiped(trackId: String) async -> [StreamInfo] {
        for instance in pipedInstances {
            guard let url = URL(string: "\(instance)/streams/\(trackId)") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.5
            
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let audioStreams = json["audioStreams"] as? [[String: Any]] else {
                continue
            }
            
            if let dur = json["duration"] as? Int, dur > 0 && dur < 60 {
                continue
            }
            
            var candidates: [StreamInfo] = []
            for stream in audioStreams {
                guard let urlString = stream["url"] as? String,
                      let streamURL = URL(string: urlString) else { continue }
                let rawBitrate = stream["bitrate"] as? Int ?? 128000
                let bitrate = rawBitrate > 1000 ? rawBitrate / 1000 : rawBitrate
                let mime = stream["mimeType"] as? String ?? "audio/mp4"
                let codec = stream["codec"] as? String
                // Never claim lossless unless the actual format/codec is genuinely lossless
                let isGenuineLossless = StreamInfo.evaluateGenuineLossless(
                    format: mime,
                    codec: StreamInfo.detectCodec(from: mime, explicitCodec: codec),
                    claimedLossless: false
                )
                candidates.append(
                    StreamInfo(
                        streamURL: streamURL,
                        format: mime,
                        codec: codec,
                        bitrate: max(32, bitrate),
                        isLossless: isGenuineLossless,
                        sampleRate: 48000,
                        sourceId: "piped",
                        sourceIsDirect: false
                    )
                )
            }
            let ranked = StreamInfo.selectTopDistinctQualityLevels(from: candidates, maxLevels: 3)
            if !ranked.isEmpty {
                return ranked
            }
        }
        return []
    }
    
    // MARK: - 3. Invidious Streams
    private func extractViaInvidious(trackId: String) async -> StreamInfo? {
        return await extractTiersViaInvidious(trackId: trackId).first
    }
    
    private func extractTiersViaInvidious(trackId: String) async -> [StreamInfo] {
        for instance in invidiousInstances {
            guard let url = URL(string: "\(instance)/api/v1/videos/\(trackId)") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.5
            
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            if let lengthSec = json["lengthSeconds"] as? Int, lengthSec > 0 && lengthSec < 60 {
                continue
            }
            
            var candidates: [StreamInfo] = []
            if let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
                for fmt in adaptiveFormats {
                    let mime = fmt["type"] as? String ?? ""
                    guard mime.contains("audio"),
                          let urlString = fmt["url"] as? String,
                          let streamURL = URL(string: urlString) else { continue }
                    let bitrateStr = fmt["bitrate"] as? String ?? "128000"
                    let rawBitrate = Int(bitrateStr) ?? (fmt["bitrate"] as? Int) ?? 128000
                    let bitrate = rawBitrate > 1000 ? rawBitrate / 1000 : rawBitrate
                    let sampleRate = Double(fmt["audioSampleRate"] as? String ?? "44100") ?? 44100
                    candidates.append(
                        StreamInfo(
                            streamURL: streamURL,
                            format: mime,
                            bitrate: max(32, bitrate),
                            isLossless: false,
                            sampleRate: sampleRate,
                            sourceId: "invidious",
                            sourceIsDirect: false
                        )
                    )
                }
            }
            let ranked = StreamInfo.selectTopDistinctQualityLevels(from: candidates, maxLevels: 3)
            if !ranked.isEmpty {
                return ranked
            }
        }
        return []
    }
}
