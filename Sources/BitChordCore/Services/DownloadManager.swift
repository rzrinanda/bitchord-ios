import Foundation

public struct DownloadedTrack: Identifiable, Codable, Sendable {
    public var id: String { track.id }
    public let track: Track
    public let localFilePath: String
    public let downloadedAt: Date
    public let fileSize: Int64
    
    public init(track: Track, localFilePath: String, downloadedAt: Date = Date(), fileSize: Int64 = 0) {
        self.track = track
        self.localFilePath = localFilePath
        self.downloadedAt = downloadedAt
        self.fileSize = fileSize
    }
}

public actor DownloadManager {
    public static let shared = DownloadManager()
    
    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    private let indexFileURL: URL
    
    private var downloadedTracksMap: [String: DownloadedTrack] = [:]
    
    public init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.downloadsDirectory = docs.appendingPathComponent("BitChord/Downloads", isDirectory: true)
        self.indexFileURL = downloadsDirectory.appendingPathComponent("downloads_index.json")
        
        if !fileManager.fileExists(atPath: downloadsDirectory.path) {
            try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        }
        
        loadIndex()
    }
    
    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexFileURL),
              let list = try? JSONDecoder().decode([DownloadedTrack].self, from: data) else { return }
        for item in list {
            downloadedTracksMap[item.track.id] = item
        }
    }
    
    private func saveIndex() {
        let list = Array(downloadedTracksMap.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
    }
    
    public func isDownloaded(trackId: String) -> Bool {
        return downloadedTracksMap[trackId] != nil
    }
    
    public func getDownloadedTracks() -> [Track] {
        return downloadedTracksMap.values.map { item in
            var t = item.track
            t.streamURL = URL(fileURLWithPath: item.localFilePath)
            return t
        }
    }
    
    /// Downloads track audio file locally to device storage
    public func downloadTrack(track: Track) async throws -> Bool {
        if isDownloaded(trackId: track.id) { return true }
        
        // 1. Resolve audio stream URL if not already present
        let streamURL: URL
        if let direct = track.streamURL {
            streamURL = direct
        } else {
            let streamInfo = try await StreamExtractor.shared.extractAudioStream(trackId: track.id)
            streamURL = streamInfo.streamURL
        }
        
        // 2. Download file
        let (tempURL, response) = try await URLSession.shared.download(from: streamURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return false
        }
        
        let targetFileName = "\(sanitize(track.id)).m4a"
        let targetFileURL = downloadsDirectory.appendingPathComponent(targetFileName)
        
        if fileManager.fileExists(atPath: targetFileURL.path) {
            try? fileManager.removeItem(at: targetFileURL)
        }
        try fileManager.moveItem(at: tempURL, to: targetFileURL)
        
        let attributes = try? fileManager.attributesOfItem(atPath: targetFileURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        
        var offlineTrack = track
        offlineTrack.streamURL = targetFileURL
        
        let downloadedItem = DownloadedTrack(
            track: offlineTrack,
            localFilePath: targetFileURL.path,
            downloadedAt: Date(),
            fileSize: fileSize
        )
        
        downloadedTracksMap[track.id] = downloadedItem
        saveIndex()
        
        // Also download lyrics for this track if auto-download is active
        _ = await LyricsManager.shared.downloadLyricsToStorage(for: track)
        
        return true
    }
    
    public func removeDownload(trackId: String) {
        guard let item = downloadedTracksMap[trackId] else { return }
        try? fileManager.removeItem(atPath: item.localFilePath)
        downloadedTracksMap.removeValue(forKey: trackId)
        saveIndex()
    }
    
    public func getTotalDownloadedSizeString() -> String {
        let totalBytes = downloadedTracksMap.values.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    private func sanitize(_ string: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return string.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
