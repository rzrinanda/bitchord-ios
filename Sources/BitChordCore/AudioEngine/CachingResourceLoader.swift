import Foundation
import AVFoundation

public extension Notification.Name {
    static let bitChordStreamURLDidExpire = Notification.Name("bitChordStreamURLDidExpire")
}

public struct ByteRange: Codable, Equatable, Hashable, Sendable {
    public let start: Int64
    public let end: Int64 // inclusive
    
    public init(start: Int64, end: Int64) {
        self.start = start
        self.end = end
    }
}

public struct CacheMetadata: Codable, Sendable {
    public var contentLength: Int64
    public var contentType: String
    public var ranges: [ByteRange]
    public var lastModified: Date
    
    public init(
        contentLength: Int64 = 0,
        contentType: String = "public.mpeg-4-audio",
        ranges: [ByteRange] = [],
        lastModified: Date = Date()
    ) {
        self.contentLength = contentLength
        self.contentType = contentType
        self.ranges = ranges
        self.lastModified = lastModified
    }
}

public final class CachingResourceLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate, @unchecked Sendable {
    public static let customScheme = "bitchord-cache"
    
    public let originalURL: URL
    public let trackId: String
    public let quality: String
    public let userAgent: String
    
    public let queue = DispatchQueue(label: "com.bitchord.cachingresourceloader", qos: .userInitiated)
    private var session: URLSession!
    
    public let audioFileURL: URL
    public let metaFileURL: URL
    public private(set) var metadata: CacheMetadata
    
    private var activeTasksByRequest: [AVAssetResourceLoadingRequest: (task: URLSessionDataTask, currentOffset: Int64, targetLength: Int64)] = [:]
    private var activeTasksById: [Int: (request: AVAssetResourceLoadingRequest, currentOffset: Int64, targetLength: Int64)] = [:]
    private var backgroundFillTask: URLSessionDataTask? = nil
    
    public init(originalURL: URL, trackId: String, quality: String = "high", userAgent: String? = nil) {
        self.originalURL = originalURL
        self.trackId = trackId
        self.quality = quality
        self.userAgent = userAgent ?? "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
        
        self.audioFileURL = Self.cacheFileURL(for: trackId, quality: quality)
        self.metaFileURL = Self.metaFileURL(for: trackId, quality: quality)
        
        // Load existing metadata if available
        if let metaData = try? Data(contentsOf: self.metaFileURL),
           let loaded = try? JSONDecoder().decode(CacheMetadata.self, from: metaData) {
            self.metadata = loaded
        } else {
            self.metadata = CacheMetadata()
        }
        
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 300.0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        ensureCacheFilesExist()
    }
    
    deinit {
        session?.invalidateAndCancel()
        backgroundFillTask?.cancel()
    }
    
    // MARK: - Range & Helpers Logic
    
    public static func mergeRanges(_ ranges: [ByteRange]) -> [ByteRange] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.start < $1.start }
        var merged: [ByteRange] = [sorted[0]]
        
        for next in sorted.dropFirst() {
            let current = merged.removeLast()
            if next.start <= current.end + 1 {
                let newEnd = max(current.end, next.end)
                merged.append(ByteRange(start: current.start, end: newEnd))
            } else {
                merged.append(current)
                merged.append(next)
            }
        }
        return merged
    }
    
    public static func isRangeFullyCovered(offset: Int64, length: Int64, by ranges: [ByteRange]) -> Bool {
        guard length > 0 else { return true }
        let targetEnd = offset + length - 1
        for range in ranges {
            if range.start <= offset && range.end >= targetEnd {
                return true
            }
        }
        return false
    }
    
    public static func contentTypeUTI(from mimeOrFormat: String) -> String {
        let lower = mimeOrFormat.lowercased()
        if lower.contains("flac") {
            return "org.xiph.flac"
        } else if lower.contains("mp4") || lower.contains("m4a") || lower.contains("aac") {
            return "public.mpeg-4-audio"
        } else if lower.contains("mpeg") || lower.contains("mp3") {
            return "public.mp3"
        } else if lower.contains("wav") {
            return "com.microsoft.waveform-audio"
        }
        return "public.mpeg-4-audio"
    }
    
    // MARK: - Directory & File Management
    
    public static let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BitChordAudioCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
    
    public static func safeKey(trackId: String, quality: String) -> String {
        let raw = "\(trackId)_\(quality)"
        let invalid = CharacterSet(charactersIn: ":/\\?%*|\"<> \t\n")
        return raw.components(separatedBy: invalid).joined(separator: "_")
    }
    
    public static func cacheFileURL(for trackId: String, quality: String) -> URL {
        let key = safeKey(trackId: trackId, quality: quality)
        return cacheDirectory.appendingPathComponent("\(key).audio")
    }
    
    public static func metaFileURL(for trackId: String, quality: String) -> URL {
        let key = safeKey(trackId: trackId, quality: quality)
        return cacheDirectory.appendingPathComponent("\(key).meta.json")
    }
    
    public static func cachedFileURLIfComplete(trackId: String, quality: String) -> URL? {
        let metaFile = metaFileURL(for: trackId, quality: quality)
        let audioFile = cacheFileURL(for: trackId, quality: quality)
        guard FileManager.default.fileExists(atPath: audioFile.path),
              let metaData = try? Data(contentsOf: metaFile),
              let meta = try? JSONDecoder().decode(CacheMetadata.self, from: metaData) else {
            return nil
        }
        if meta.contentLength > 0,
           isRangeFullyCovered(offset: 0, length: meta.contentLength, by: meta.ranges) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioFile.path),
               let size = attrs[.size] as? Int64, size >= meta.contentLength {
                return audioFile
            }
        }
        return nil
    }
    
    /// Calculates the total bytes, file count, and formatted string across all BitChord audio cache directories.
    public static func calculateTotalCacheSize() -> (bytes: Int64, count: Int, formatted: String) {
        let fm = FileManager.default
        var totalBytes: Int64 = 0
        var totalCount: Int = 0
        
        let directories = [
            cacheDirectory,
            StreamExtractor.streamCacheDirectory,
            fm.temporaryDirectory.appendingPathComponent("BitChordStreamCache", isDirectory: true)
        ]
        
        var visitedPaths = Set<String>()
        for dir in directories {
            guard visitedPaths.insert(dir.path).inserted else { continue }
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else { continue }
            for file in files {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let size = (attrs[.size] as? NSNumber)?.int64Value {
                    totalBytes += size
                    totalCount += 1
                }
            }
        }
        
        let formatted: String
        if totalBytes == 0 {
            formatted = "0 KB"
        } else if totalBytes < 1024 * 1024 {
            formatted = "\(totalBytes / 1024) KB"
        } else {
            formatted = String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
        }
        
        return (totalBytes, totalCount, formatted)
    }
    
    /// Completely clears all cached audio files across all cache directories.
    public static func clearAllAudioCache() {
        let fm = FileManager.default
        let directories = [
            cacheDirectory,
            StreamExtractor.streamCacheDirectory,
            fm.temporaryDirectory.appendingPathComponent("BitChordStreamCache", isDirectory: true)
        ]
        var visitedPaths = Set<String>()
        for dir in directories {
            guard visitedPaths.insert(dir.path).inserted else { continue }
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for file in files {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }
    
    public static func evictOldCacheFiles(
        in directory: URL = CachingResourceLoader.cacheDirectory,
        maxSizeBytes: Int64 = 500 * 1024 * 1024,
        targetSizeBytes: Int64 = 400 * 1024 * 1024,
        protectedKey: String? = nil
    ) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        
        var totalSize: Int64 = 0
        var files: [(url: URL, size: Int64, date: Date, baseKey: String)] = []
        
        for fileURL in contents {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date.distantPast
            totalSize += size
            let filename = fileURL.deletingPathExtension().lastPathComponent
            let baseKey = filename.replacingOccurrences(of: ".meta", with: "")
            files.append((fileURL, size, date, baseKey))
        }
        
        guard totalSize > maxSizeBytes else { return }
        files.sort { $0.date < $1.date }
        
        for file in files {
            if let protected = protectedKey, file.baseKey.contains(protected) {
                continue
            }
            try? fm.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= targetSizeBytes {
                break
            }
        }
    }
    
    private func ensureCacheFilesExist() {
        if !FileManager.default.fileExists(atPath: audioFileURL.path) {
            FileManager.default.createFile(atPath: audioFileURL.path, contents: nil)
        }
    }
    
    private func saveMetadata() {
        metadata.lastModified = Date()
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metaFileURL, options: .atomic)
        }
    }
    
    // MARK: - Asset Creation
    
    public func createAsset() -> AVURLAsset {
        guard originalURL.scheme == "http" || originalURL.scheme == "https" else {
            return AVURLAsset(url: originalURL)
        }
        var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
        components?.scheme = Self.customScheme
        let customURL = components?.url ?? URL(string: "\(Self.customScheme)://audio/\(trackId)")!
        
        let asset = AVURLAsset(url: customURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": userAgent]
        ])
        asset.resourceLoader.setDelegate(self, queue: self.queue)
        return asset
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url, url.scheme == Self.customScheme else {
            return false
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.handleLoadingRequest(loadingRequest)
        }
        return true
    }
    
    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let taskInfo = self.activeTasksByRequest.removeValue(forKey: loadingRequest) {
                taskInfo.task.cancel()
                self.activeTasksById.removeValue(forKey: taskInfo.task.taskIdentifier)
            }
        }
    }
    
    // MARK: - Request Handling
    
    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        // 1. Content Information Request
        if let contentInfo = loadingRequest.contentInformationRequest {
            if metadata.contentLength > 0 {
                contentInfo.contentType = metadata.contentType
                contentInfo.contentLength = metadata.contentLength
                contentInfo.isByteRangeAccessSupported = true
            } else {
                fetchContentInformation(for: loadingRequest)
                return
            }
        }
        
        // 2. Data Request
        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            return
        }
        
        let offset = dataRequest.requestedOffset
        let length = Int64(dataRequest.requestedLength)
        
        // Check if fully in disk cache
        if Self.isRangeFullyCovered(offset: offset, length: length, by: metadata.ranges) {
            if let fileHandle = try? FileHandle(forReadingFrom: audioFileURL) {
                defer { try? fileHandle.close() }
                do {
                    try fileHandle.seek(toOffset: UInt64(offset))
                    let data = fileHandle.readData(ofLength: Int(length))
                    dataRequest.respond(with: data)
                    loadingRequest.finishLoading()
                    return
                } catch {
                    // Fallback to network if seek/read failed
                }
            }
        }
        
        // Fetch from network with Range header
        startNetworkDataTask(for: loadingRequest, offset: offset, length: length)
    }
    
    private func fetchContentInformation(for loadingRequest: AVAssetResourceLoadingRequest) {
        var req = URLRequest(url: originalURL)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("bytes=0-1", forHTTPHeaderField: "Range")
        
        let task = session.dataTask(with: req) { [weak self] _, response, error in
            guard let self = self else { return }
            self.queue.async {
                if let error = error as? URLError, error.code == .cancelled { return }
                
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 403 || http.statusCode == 410 {
                        NotificationCenter.default.post(
                            name: .bitChordStreamURLDidExpire,
                            object: nil,
                            userInfo: ["trackId": self.trackId]
                        )
                        loadingRequest.finishLoading(with: URLError(.userAuthenticationRequired))
                        return
                    }
                    
                    var totalLength: Int64 = 0
                    if let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
                       let totalStr = contentRange.components(separatedBy: "/").last,
                       let parsed = Int64(totalStr) {
                        totalLength = parsed
                    } else if let lenStr = http.value(forHTTPHeaderField: "Content-Length"),
                              let parsed = Int64(lenStr) {
                        totalLength = parsed
                    }
                    
                    let mime = http.mimeType ?? "audio/mp4"
                    let uti = Self.contentTypeUTI(from: mime)
                    
                    self.metadata.contentLength = totalLength
                    self.metadata.contentType = uti
                    self.saveMetadata()
                    
                    if let contentInfo = loadingRequest.contentInformationRequest {
                        contentInfo.contentType = uti
                        contentInfo.contentLength = totalLength
                        contentInfo.isByteRangeAccessSupported = true
                    }
                }
                
                if let dataReq = loadingRequest.dataRequest {
                    let offset = dataReq.requestedOffset
                    let length = Int64(dataReq.requestedLength)
                    self.startNetworkDataTask(for: loadingRequest, offset: offset, length: length)
                } else {
                    loadingRequest.finishLoading()
                }
            }
        }
        task.resume()
    }
    
    private func startNetworkDataTask(for loadingRequest: AVAssetResourceLoadingRequest, offset: Int64, length: Int64) {
        var req = URLRequest(url: originalURL)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        
        let task = session.dataTask(with: req)
        activeTasksByRequest[loadingRequest] = (task: task, currentOffset: offset, targetLength: length)
        activeTasksById[task.taskIdentifier] = (request: loadingRequest, currentOffset: offset, targetLength: length)
        task.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 403 || http.statusCode == 410 {
                NotificationCenter.default.post(
                    name: .bitChordStreamURLDidExpire,
                    object: nil,
                    userInfo: ["trackId": self.trackId]
                )
            }
            if self.metadata.contentLength == 0 {
                if let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
                   let totalStr = contentRange.components(separatedBy: "/").last,
                   let parsed = Int64(totalStr) {
                    self.metadata.contentLength = parsed
                }
                self.saveMetadata()
            }
        }
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async { [weak self] in
            guard let self = self,
                  var taskInfo = self.activeTasksById[dataTask.taskIdentifier] else { return }
            
            let offset = taskInfo.currentOffset
            
            // 1. Respond to AVPlayer
            taskInfo.request.dataRequest?.respond(with: data)
            
            // 2. Write to disk cache
            self.writeCacheChunk(offset: offset, data: data)
            
            taskInfo.currentOffset += Int64(data.count)
            self.activeTasksById[dataTask.taskIdentifier] = taskInfo
            self.activeTasksByRequest[taskInfo.request] = (task: dataTask, currentOffset: taskInfo.currentOffset, targetLength: taskInfo.targetLength)
            
            // Check if full requested range has been fed
            if let dr = taskInfo.request.dataRequest,
               taskInfo.currentOffset >= dr.requestedOffset + Int64(dr.requestedLength) {
                taskInfo.request.finishLoading()
                self.activeTasksById.removeValue(forKey: dataTask.taskIdentifier)
                self.activeTasksByRequest.removeValue(forKey: taskInfo.request)
                dataTask.cancel()
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async { [weak self] in
            guard let self = self,
                  let taskInfo = self.activeTasksById.removeValue(forKey: task.taskIdentifier) else { return }
            self.activeTasksByRequest.removeValue(forKey: taskInfo.request)
            
            if let error = error {
                if (error as? URLError)?.code != .cancelled {
                    taskInfo.request.finishLoading(with: error)
                }
            } else {
                taskInfo.request.finishLoading()
            }
            
            self.saveMetadata()
            Self.evictOldCacheFiles(protectedKey: self.trackId)
        }
    }
    
    private func writeCacheChunk(offset: Int64, data: Data) {
        guard !data.isEmpty else { return }
        if let fileHandle = try? FileHandle(forWritingTo: audioFileURL) {
            defer { try? fileHandle.close() }
            do {
                try fileHandle.seek(toOffset: UInt64(offset))
                try fileHandle.write(contentsOf: data)
            } catch {}
        }
        let newRange = ByteRange(start: offset, end: offset + Int64(data.count) - 1)
        var updated = metadata.ranges
        updated.append(newRange)
        metadata.ranges = Self.mergeRanges(updated)
    }
}
