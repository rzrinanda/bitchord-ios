import Foundation

public struct StreamInfo: Sendable {
    public let streamURL: URL
    public let format: String
    public let bitrate: Int
    public let isLossless: Bool
    public let sampleRate: Double?
    
    public init(
        streamURL: URL,
        format: String = "audio/mp4",
        bitrate: Int = 256,
        isLossless: Bool = false,
        sampleRate: Double? = 44100
    ) {
        self.streamURL = streamURL
        self.format = format
        self.bitrate = bitrate
        self.isLossless = isLossless
        self.sampleRate = sampleRate
    }
}

public actor StreamExtractor {
    public static let shared = StreamExtractor()
    
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
    
    public init() {}
    
    /// Resolves direct audio stream URL for a track/video ID
    public func extractAudioStream(
        trackId: String,
        preferredQuality: AudioQuality = .high
    ) async throws -> StreamInfo {
        // Strategy 1: Direct YouTube Innertube Player API (iOS Client)
        if let direct = await extractViaYouTubeInnertube(trackId: trackId) {
            return direct
        }
        
        // Strategy 2: Piped Audio Streams
        if let piped = await extractViaPiped(trackId: trackId, preferredQuality: preferredQuality) {
            return piped
        }
        
        // Strategy 3: Invidious Audio Streams
        if let invidious = await extractViaInvidious(trackId: trackId) {
            return invidious
        }
        
        throw URLError(.cannotFindHost)
    }
    
    // MARK: - 1. Direct YouTube Innertube (iOS Client - Returns Direct URLs)
    private func extractViaYouTubeInnertube(trackId: String) async -> StreamInfo? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else { return nil }
        
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
        request.timeoutInterval = 7.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }
        
        // Parse adaptiveFormats
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            // Find highest bitrate audio stream
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
                return StreamInfo(
                    streamURL: streamURL,
                    format: mime,
                    bitrate: bitrate,
                    isLossless: bitrate >= 256,
                    sampleRate: 44100
                )
            }
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
