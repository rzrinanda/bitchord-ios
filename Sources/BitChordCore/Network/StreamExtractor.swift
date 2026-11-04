import Foundation

public struct StreamInfo: Sendable {
    public let streamURL: URL
    public let format: String
    public let bitrate: Int
    public let isLossless: Bool
    public let sampleRate: Double?
    public let bitDepth: Int?
    
    public init(
        streamURL: URL,
        format: String = "audio/mp4",
        bitrate: Int = 256,
        isLossless: Bool = false,
        sampleRate: Double? = 44100,
        bitDepth: Int? = nil
    ) {
        self.streamURL = streamURL
        self.format = format
        self.bitrate = bitrate
        self.isLossless = isLossless
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
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
    
    /// Resolves direct audio stream URL for a track/video ID with multi-source fallback
    public func extractAudioStream(
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        preferredQuality: AudioQuality = .high
    ) async throws -> StreamInfo {
        var effectiveVideoId = trackId
        
        // If trackId is an alias or placeholder, resolve real YouTube 11-char videoId first
        if effectiveVideoId.count != 11 || effectiveVideoId.hasPrefix("yt_") {
            if let title = title, let resolvedId = await resolveYouTubeVideoId(title: title, artist: artist) {
                effectiveVideoId = resolvedId
            }
        }
        
        // Strategy 0: Custom Addon Stream (e.g. SoundFean Qobuz Hi-Res FLAC)
        let activeAddons = await MainActor.run {
            BitChordSettings.shared.addonSources.filter { $0.isEnabled && $0.resources.contains("stream") }
        }
        if let title = title {
            for addon in activeAddons {
                if let addonStream = await AddonService.shared.resolveStream(trackTitle: title, artist: artist, addon: addon) {
                    return addonStream
                }
            }
        }
        
        // Strategy 1: Direct YouTube Innertube Player API (iOS Client - Full Length Audio)
        if effectiveVideoId.count == 11, let direct = await extractViaYouTubeInnertube(trackId: effectiveVideoId) {
            return direct
        }
        
        // Strategy 2: Direct YouTube Innertube Player API (Android Client - Full Length Audio)
        if effectiveVideoId.count == 11, let androidStream = await extractViaYouTubeAndroid(trackId: effectiveVideoId) {
            return androidStream
        }
        
        // Strategy 3: Piped Audio Streams (Full Length Audio)
        if effectiveVideoId.count == 11, let piped = await extractViaPiped(trackId: effectiveVideoId, preferredQuality: preferredQuality) {
            return piped
        }
        
        // Strategy 4: Invidious Audio Streams (Full Length Audio)
        if effectiveVideoId.count == 11, let invidious = await extractViaInvidious(trackId: effectiveVideoId) {
            return invidious
        }
        
        throw URLError(.cannotFindHost)
    }
    
    // Resolve YouTube 11-char Video ID from search (Full-length official audio only)
    private func resolveYouTubeVideoId(title: String, artist: String?) async -> String? {
        if let ytMusicId = await YTMusicClient.shared.resolveYouTubeVideoId(title: title, artist: artist) {
            return ytMusicId
        }
        
        let query = "\(title) \(artist ?? "") Official Audio".trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search?key=\(innertubeKey)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtube/19.29.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 4.0
        
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let contents = json["contents"] as? [String: Any],
           let sectionList = contents["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            for section in sections {
                if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                   let contentsArray = itemSection["contents"] as? [[String: Any]] {
                    for item in contentsArray {
                        if let videoRenderer = item["videoRenderer"] as? [String: Any],
                           let vId = videoRenderer["videoId"] as? String, vId.count == 11 {
                            // Verify duration is not a short/teaser (< 60s)
                            if let lengthText = (videoRenderer["lengthText"] as? [String: Any])?["simpleText"] as? String {
                                let parts = lengthText.split(separator: ":")
                                if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), (m * 60 + s) < 60 {
                                    continue
                                }
                            }
                            return vId
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - 1. Direct YouTube Innertube (iOS Client with Public Key)
    private func extractViaYouTubeInnertube(trackId: String) async -> StreamInfo? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(innertubeKey)") else { return nil }
        
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
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)", forHTTPHeaderField: "User-Agent")
        request.setValue("5", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("19.29.1", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 6.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }
        
        // Reject short clips / teasers (< 60s)
        if let videoDetails = json["videoDetails"] as? [String: Any],
           let lengthStr = videoDetails["lengthSeconds"] as? String,
           let lengthSec = Int(lengthStr), lengthSec > 0 && lengthSec < 60 {
            return nil
        }
        
        // Parse adaptiveFormats (sorted by highest bitrate)
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            let audioStreams = adaptiveFormats.filter { format in
                let mime = format["mimeType"] as? String ?? ""
                return mime.contains("audio") && format["url"] != nil
            }
            
            let sorted = audioStreams.sorted {
                let b1 = $0["bitrate"] as? Int ?? 0
                let b2 = $1["bitrate"] as? Int ?? 0
                return b1 > b2
            }
            
            if let best = sorted.first,
               let urlString = best["url"] as? String,
               let streamURL = URL(string: urlString) {
                let bitrate = (best["bitrate"] as? Int ?? 256000) / 1000
                let mime = best["mimeType"] as? String ?? "audio/mp4"
                let sampleRate = Double(best["audioSampleRate"] as? String ?? "44100") ?? 44100
                return StreamInfo(
                    streamURL: streamURL,
                    format: mime,
                    bitrate: bitrate,
                    isLossless: false,
                    sampleRate: sampleRate
                )
            }
        }
        
        // Check HLS manifest
        if let hlsManifest = streamingData["hlsManifestUrl"] as? String,
           let hlsURL = URL(string: hlsManifest) {
            return StreamInfo(streamURL: hlsURL, format: "application/x-mpegURL", bitrate: 256, isLossless: false)
        }
        
        // Fallback to combined formats
        if let formats = streamingData["formats"] as? [[String: Any]],
           let firstFormat = formats.first,
           let urlString = firstFormat["url"] as? String,
           let streamURL = URL(string: urlString) {
            return StreamInfo(streamURL: streamURL, format: "video/mp4", bitrate: 128)
        }
        
        return nil
    }
    
    // MARK: - 1b. Direct YouTube Innertube (Android Client - Full Length Audio)
    private func extractViaYouTubeAndroid(trackId: String) async -> StreamInfo? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(innertubeKey)") else { return nil }
        
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": "19.29.35",
                    "androidSdkVersion": 34,
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": trackId
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.android.youtube/19.29.35 (Linux; U; Android 14; en_US)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 6.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }
        
        // Reject short clips / teasers (< 60s)
        if let videoDetails = json["videoDetails"] as? [String: Any],
           let lengthStr = videoDetails["lengthSeconds"] as? String,
           let lengthSec = Int(lengthStr), lengthSec > 0 && lengthSec < 60 {
            return nil
        }
        
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            let audioStreams = adaptiveFormats.filter { format in
                let mime = format["mimeType"] as? String ?? ""
                return mime.contains("audio") && format["url"] != nil
            }.sorted {
                let b1 = $0["bitrate"] as? Int ?? 0
                let b2 = $1["bitrate"] as? Int ?? 0
                return b1 > b2
            }
            if let best = audioStreams.first,
               let urlString = best["url"] as? String,
               let streamURL = URL(string: urlString) {
                let bitrate = (best["bitrate"] as? Int ?? 256000) / 1000
                let sampleRate = Double(best["audioSampleRate"] as? String ?? "44100") ?? 44100
                return StreamInfo(
                    streamURL: streamURL,
                    format: "audio/mp4",
                    bitrate: bitrate,
                    isLossless: false,
                    sampleRate: sampleRate
                )
            }
        }
        return nil
    }
    
    // MARK: - 2. Piped Streams
    private func extractViaPiped(trackId: String, preferredQuality: AudioQuality) async -> StreamInfo? {
        for instance in pipedInstances {
            guard let url = URL(string: "\(instance)/streams/\(trackId)") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let audioStreams = json["audioStreams"] as? [[String: Any]] else {
                continue
            }
            
            let sorted = audioStreams.sorted {
                let b1 = $0["bitrate"] as? Int ?? 0
                let b2 = $1["bitrate"] as? Int ?? 0
                return b1 > b2
            }
            
            if let best = sorted.first,
               let urlString = best["url"] as? String,
               let streamURL = URL(string: urlString) {
                let bitrate = (best["bitrate"] as? Int ?? 256000) / 1000
                return StreamInfo(
                    streamURL: streamURL,
                    format: best["mimeType"] as? String ?? "audio/mp4",
                    bitrate: bitrate,
                    isLossless: preferredQuality == .lossless
                )
            }
        }
        return nil
    }
    
    // MARK: - 3. Invidious Streams
    private func extractViaInvidious(trackId: String) async -> StreamInfo? {
        for instance in invidiousInstances {
            guard let url = URL(string: "\(instance)/api/v1/videos/\(trackId)") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            if let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
                let audioFormats = adaptiveFormats.filter { ($0["type"] as? String ?? "").contains("audio") }
                if let first = audioFormats.first,
                   let urlString = first["url"] as? String,
                   let streamURL = URL(string: urlString) {
                    return StreamInfo(streamURL: streamURL, format: first["type"] as? String ?? "audio/mp4", bitrate: 128)
                }
            }
        }
        return nil
    }
}
