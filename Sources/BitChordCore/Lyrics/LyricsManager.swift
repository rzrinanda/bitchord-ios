import Foundation

public actor LyricsManager {
    public static let shared = LyricsManager()
    
    private let parser: LRCParser
    private let storage: LyricsStorageManager
    private let client: LRCLIBClient
    
    public init(
        parser: LRCParser = LRCParser(),
        storage: LyricsStorageManager = .shared,
        client: LRCLIBClient = .shared
    ) {
        self.parser = parser
        self.storage = storage
        self.client = client
    }
    
    /// Loads lyrics for a given track with automatic caching, storage fallback, and network lookup.
    public func loadLyrics(for track: Track) async -> Lyrics? {
        // Step 1: Check Local Storage / In-memory Cache
        if let cached = await storage.getLyrics(for: track.id) {
            return cached
        }
        
        // Step 2: Fetch from Online Provider (LRCLIB)
        do {
            let response = try await client.fetchLyrics(
                trackName: track.title,
                artistName: track.artist,
                albumName: track.album,
                duration: track.duration
            )
            
            var lyrics: Lyrics
            var rawLRC: String? = nil
            
            if let synced = response.syncedLyrics, !synced.isEmpty {
                rawLRC = synced
                lyrics = parser.parse(trackId: track.id, lrcContent: synced, provider: "LRCLIB")
            } else if let plain = response.plainLyrics, !plain.isEmpty {
                lyrics = Lyrics(
                    trackId: track.id,
                    isSynced: false,
                    lines: [],
                    plainLyrics: plain,
                    provider: "LRCLIB",
                    source: .network
                )
            } else {
                return nil
            }
            
            // Step 3: Process through storage manager (auto-downloads to disk IF toggle is enabled)
            await storage.processRetrievedLyrics(lyrics: lyrics, rawLRC: rawLRC)
            
            return lyrics
        } catch {
            // Step 3 (Fallback): Fetch from KuGou API
            if let kugouLyrics = await fetchKuGouLyrics(for: track) {
                await storage.processRetrievedLyrics(lyrics: kugouLyrics, rawLRC: kugouLyrics.plainLyrics)
                return kugouLyrics
            }
            return nil
        }
    }
    
    /// KuGou Lyrics API Fallback for Asian / Global tracks
    private func fetchKuGouLyrics(for track: Track) async -> Lyrics? {
        guard let query = "\(track.artist) \(track.title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=\(query)") else {
            return nil
        }
        
        var req = URLRequest(url: searchURL)
        req.timeoutInterval = 5.0
        
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let id = first["id"] as? String ?? (first["id"] as? Int).map(String.init),
              let accesskey = first["accesskey"] as? String,
              let downloadURL = URL(string: "http://lyrics.kugou.com/download?ver=1&client=pc&id=\(id)&accesskey=\(accesskey)&fmt=lrc&charset=utf8") else {
            return nil
        }
        
        guard let (dlData, dlResp) = try? await URLSession.shared.data(from: downloadURL),
              let dlHttp = dlResp as? HTTPURLResponse, dlHttp.statusCode == 200,
              let dlJson = try? JSONSerialization.jsonObject(with: dlData) as? [String: Any],
              let b64 = dlJson["content"] as? String,
              let decodedData = Data(base64Encoded: b64),
              let lrcString = String(data: decodedData, encoding: .utf8) else {
            return nil
        }
        
        return parser.parse(trackId: track.id, lrcContent: lrcString, provider: "KuGou")
    }
    
    /// User switch: enable or disable auto-download to storage
    public func setAutoDownloadLyrics(_ enabled: Bool) async {
        await storage.setAutoDownload(enabled)
    }
    
    public func isAutoDownloadEnabled() async -> Bool {
        return await storage.autoDownloadToStorage
    }
    
    /// Checks if lyrics are permanently saved to storage
    public func isLyricsSavedLocally(for trackId: String) async -> Bool {
        return await storage.isLyricsStoredOnDisk(trackId: trackId)
    }
    
    /// Explicitly save lyrics to offline disk storage
    public func downloadLyricsToStorage(for track: Track) async -> Bool {
        if let existing = await storage.getLyrics(for: track.id) {
            let raw = await storage.getRawLRC(for: track.id)
            await storage.manuallySaveToDisk(lyrics: existing, rawLRC: raw)
            return true
        }
        
        // If not loaded yet, fetch and force disk save
        do {
            let response = try await client.fetchLyrics(
                trackName: track.title,
                artistName: track.artist,
                albumName: track.album,
                duration: track.duration
            )
            if let synced = response.syncedLyrics {
                let lyrics = parser.parse(trackId: track.id, lrcContent: synced)
                await storage.processRetrievedLyrics(lyrics: lyrics, rawLRC: synced, forceDiskSave: true)
                return true
            }
        } catch {}
        return false
    }
    
    /// Delete lyrics from disk storage
    public func deleteLyricsFromStorage(for trackId: String) async {
        await storage.deleteLyrics(for: trackId)
    }
    
    /// Wipes all downloaded lyrics
    public func clearAllDownloadedLyrics() async {
        await storage.clearAllDiskStorage()
    }
    
    /// Formatted disk usage for lyrics
    public func getStorageUsageString() async -> String {
        return await storage.formattedStorageSize()
    }
    
    /// Number of tracks with offline lyrics
    public func getDownloadedLyricsCount() async -> Int {
        return await storage.countStoredTracks()
    }
}
