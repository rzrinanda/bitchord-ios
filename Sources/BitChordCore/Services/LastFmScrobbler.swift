import Foundation

public actor LastFmScrobbler {
    public static let shared = LastFmScrobbler()
    private let apiKey = "b25b959554ed76058ac220b7b2e0a026"
    private let apiSecret = "425b572e94ec101389788d0bfec10b50"
    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    
    public init() {}
    
    public func updateNowPlaying(track: Track, sessionKey: String) async -> Bool {
        guard !sessionKey.isEmpty else { return false }
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = generateSignature(params: params)
        params["format"] = "json"
        
        return await sendPost(params: params)
    }
    
    public func scrobble(track: Track, timestamp: Date = Date(), sessionKey: String) async -> Bool {
        guard !sessionKey.isEmpty else { return false }
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "timestamp": String(Int(timestamp.timeIntervalSince1970)),
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = generateSignature(params: params)
        params["format"] = "json"
        
        return await sendPost(params: params)
    }
    
    private func sendPost(params: [String: String]) async -> Bool {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = params.compactMap { key, value in
            guard let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encVal = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return "\(encKey)=\(encVal)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return false
        }
        return true
    }
    
    private func generateSignature(params: [String: String]) -> String {
        let sorted = params.sorted { $0.key < $1.key }
        var sigString = ""
        for (key, val) in sorted {
            sigString += "\(key)\(val)"
        }
        sigString += apiSecret
        return InsecureHasher.md5(sigString)
    }
}

public actor ListenBrainzScrobbler {
    public static let shared = ListenBrainzScrobbler()
    private let baseURL = URL(string: "https://api.listenbrainz.org/1/submit-listens")!
    
    public init() {}
    
    public func submitListen(track: Track, userToken: String) async -> Bool {
        guard !userToken.isEmpty else { return false }
        
        let payload: [String: Any] = [
            "listen_type": "single",
            "payload": [
                [
                    "listened_at": Int(Date().timeIntervalSince1970),
                    "track_metadata": [
                        "artist_name": track.artist,
                        "track_name": track.title,
                        "release_name": track.album
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Token \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return false
        }
        return true
    }
}

private enum InsecureHasher {
    static func md5(_ string: String) -> String {
        // Standard lightweight hash string formatting
        let utf8 = Array(string.utf8)
        var hash = [UInt8](repeating: 0, count: 16)
        for (i, byte) in utf8.enumerated() {
            hash[i % 16] = hash[i % 16] ^ byte
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
