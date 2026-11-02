import Foundation

/// Manages caching and persistence of synchronized lyrics.
/// Supports switching between auto-downloading lyrics to persistent disk storage or keeping them in-memory only.
public actor LyricsStorageManager {
    public static let shared = LyricsStorageManager()
    
    /// User preference: whether to automatically persist fetched lyrics to disk storage.
    public var autoDownloadToStorage: Bool {
        didSet {
            UserDefaults.standard.set(autoDownloadToStorage, forKey: Self.autoDownloadPrefKey)
        }
    }
    
    private static let autoDownloadPrefKey = "BitChord.Lyrics.AutoDownloadToStorage"
    
    // In-memory cache for fast session access without disk I/O overhead
    private var memoryCache: [String: Lyrics] = [:]
    private var rawLRCMemoryCache: [String: String] = [:]
    
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    
    public init(
        customStorageURL: URL? = nil,
        defaultAutoDownload: Bool = true
    ) {
        if let storedSetting = UserDefaults.standard.object(forKey: Self.autoDownloadPrefKey) as? Bool {
            self.autoDownloadToStorage = storedSetting
        } else {
            self.autoDownloadToStorage = defaultAutoDownload
            UserDefaults.standard.set(defaultAutoDownload, forKey: Self.autoDownloadPrefKey)
        }
        
        if let customURL = customStorageURL {
            self.storageDirectory = customURL
        } else {
            let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            let baseDir = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.storageDirectory = baseDir.appendingPathComponent("BitChord/LyricsCache", isDirectory: true)
        }
        
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func setAutoDownload(_ enabled: Bool) {
        self.autoDownloadToStorage = enabled
    }
    
    /// Stores retrieved lyrics according to the auto-download switch.
    /// If autoDownload is ON: writes both to in-memory session cache AND disk storage.
    /// If autoDownload is OFF: writes ONLY to in-memory session cache; disk remains untouched.
    public func processRetrievedLyrics(
        lyrics: Lyrics,
        rawLRC: String? = nil,
        forceDiskSave: Bool = false
    ) async {
        // Always cache in memory for the active session
        memoryCache[lyrics.trackId] = lyrics
        if let raw = rawLRC {
            rawLRCMemoryCache[lyrics.trackId] = raw
        }
        
        // Save to persistent disk storage if enabled or forced
        if autoDownloadToStorage || forceDiskSave {
            await saveToDisk(lyrics: lyrics, rawLRC: rawLRC)
        }
    }
    
    /// Explicitly save a specific track's lyrics to persistent storage (e.g. user tapped "Download Lyrics Offline")
    public func manuallySaveToDisk(lyrics: Lyrics, rawLRC: String? = nil) async {
        await saveToDisk(lyrics: lyrics, rawLRC: rawLRC)
    }
    
    private func saveToDisk(lyrics: Lyrics, rawLRC: String?) async {
        ensureDirectoryExists()
        var updatedLyrics = lyrics
        updatedLyrics.source = .localDisk
        
        let fileURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(lyrics.trackId)).json")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(updatedLyrics)
            try data.write(to: fileURL, options: .atomic)
            
            // Also save raw .lrc file if present
            if let rawLRC = rawLRC {
                let lrcURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(lyrics.trackId)).lrc")
                try rawLRC.write(to: lrcURL, atomically: true, encoding: .utf8)
            }
            
            // Update memory cache with source marked as localDisk
            memoryCache[lyrics.trackId] = updatedLyrics
        } catch {
            print("[BitChord Lyrics] Error saving to storage: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves lyrics for a track ID: Checks in-memory cache first, then disk storage.
    public func getLyrics(for trackId: String) -> Lyrics? {
        if let inMemory = memoryCache[trackId] {
            return inMemory
        }
        
        let fileURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(trackId)).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let lyrics = try decoder.decode(Lyrics.self, from: data)
            // Cache in memory for quick reuse
            memoryCache[trackId] = lyrics
            return lyrics
        } catch {
            return nil
        }
    }
    
    /// Checks whether lyrics for trackId are permanently stored on local disk.
    public func isLyricsStoredOnDisk(trackId: String) -> Bool {
        let fileURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(trackId)).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Gets raw LRC text if available from memory or disk
    public func getRawLRC(for trackId: String) -> String? {
        if let mem = rawLRCMemoryCache[trackId] {
            return mem
        }
        let lrcURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(trackId)).lrc")
        return try? String(contentsOf: lrcURL, encoding: .utf8)
    }
    
    /// Deletes stored lyrics for a specific track from disk and memory
    public func deleteLyrics(for trackId: String) {
        memoryCache.removeValue(forKey: trackId)
        rawLRCMemoryCache.removeValue(forKey: trackId)
        
        let jsonURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(trackId)).json")
        let lrcURL = storageDirectory.appendingPathComponent("\(sanitizeFilename(trackId)).lrc")
        
        try? fileManager.removeItem(at: jsonURL)
        try? fileManager.removeItem(at: lrcURL)
    }
    
    /// Wipes all persistent stored lyrics from disk
    public func clearAllDiskStorage() {
        let items = (try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)) ?? []
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
    
    /// Clears session in-memory cache
    public func clearMemoryCache() {
        memoryCache.removeAll()
        rawLRCMemoryCache.removeAll()
    }
    
    /// Computes total storage consumed by cached lyrics files in bytes
    public func calculateStorageSizeBytes() -> Int64 {
        guard let items = try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalBytes: Int64 = 0
        for item in items {
            if let resource = try? item.resourceValues(forKeys: [.fileSizeKey]), let size = resource.fileSize {
                totalBytes += Int64(size)
            }
        }
        return totalBytes
    }
    
    /// Formatted storage size (e.g., "1.4 MB", "340 KB")
    public func formattedStorageSize() -> String {
        let bytes = calculateStorageSizeBytes()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Count of lyrics files saved to disk
    public func countStoredTracks() -> Int {
        let items = (try? fileManager.contentsOfDirectory(atPath: storageDirectory.path)) ?? []
        return items.filter { $0.hasSuffix(".json") }.count
    }
    
    private func sanitizeFilename(_ string: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return string.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
