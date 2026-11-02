import Foundation

public struct StreamInfo: Sendable {
    public let streamURL: URL
    public let format: String
    public let bitrate: Int
    public let isLossless: Bool
    public let sampleRate: Double?
}

public actor StreamExtractor {
    public static let shared = StreamExtractor()
    
    // Fallback public Invidious / Piped instances if direct client player encounters signature deciphering
    private let fallbackInstances = [
        "https://pipedapi.kavin.rocks",
        "https://api.piped.privacydev.net",
        "https://invidious.nerdvpn.de"
    ]
    
    public init() {}
    
    /// Resolves direct audio stream URL for a YouTube video/track ID
    public func extractAudioStream(
        trackId: String,
        preferredQuality: AudioQuality = .high
    ) async throws -> StreamInfo {
        for instance in fallbackInstances {
            guard let url = URL(string: "\(instance)/streams/\(trackId)") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioStreams = json["audioStreams"] as? [[String: Any]] {
                    
                    // Filter and find best stream matching quality
                    let sortedStreams = audioStreams.sorted {
                        let b1 = $0["bitrate"] as? Int ?? 0
                        let b2 = $1["bitrate"] as? Int ?? 0
                        return b1 > b2
                    }
                    
                    if let stream = sortedStreams.first,
                       let urlString = stream["url"] as? String,
                       let streamURL = URL(string: urlString) {
                        let bitrate = stream["bitrate"] as? Int ?? preferredQuality.bitrate
                        let mimeType = stream["mimeType"] as? String ?? "audio/mp4"
                        return StreamInfo(
                            streamURL: streamURL,
                            format: mimeType,
                            bitrate: bitrate,
                            isLossless: preferredQuality == .lossless,
                            sampleRate: 44100
                        )
                    }
                }
            } catch {
                continue
            }
        }
        
        throw URLError(.cannotFindHost)
    }
}
