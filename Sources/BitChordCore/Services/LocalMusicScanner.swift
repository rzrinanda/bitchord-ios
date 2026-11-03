import Foundation
import AVFoundation
import CryptoKit
#if canImport(MediaPlayer) && os(iOS)
import MediaPlayer
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Scans on-device audio (app Documents / Files "On My iPhone", a user-picked folder,
/// and optionally the Apple Music / iTunes synced library) according to Local Music settings.
@MainActor
public final class LocalMusicScanner: ObservableObject {
    public static let shared = LocalMusicScanner()
    
    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var lastScanDate: Date?
    
    nonisolated public static let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "flac", "wav", "aiff", "aif", "caf", "alac", "opus", "ogg", "mp4"]
    private static let bookmarkKey = "BitChord.LocalMusic.FolderBookmark"
    private static let lastScanKey = "BitChord.LocalMusic.LastScan"
    
    private var accessedFolderURL: URL?
    
    private init() {
        tracks = Self.loadIndex()
        if let ts = UserDefaults.standard.object(forKey: Self.lastScanKey) as? Date {
            lastScanDate = ts
        }
        _ = resolveCustomFolder()
    }
    
    // MARK: - Folder selection
    
    /// The user-picked folder (security scoped), if any.
    public var customFolderURL: URL? { accessedFolderURL }
    
    public func setCustomFolder(_ url: URL?) {
        accessedFolderURL?.stopAccessingSecurityScopedResource()
        accessedFolderURL = nil
        guard let url = url else {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            BitChordSettings.shared.localMusicFolder = "All audio folders"
            return
        }
        _ = url.startAccessingSecurityScopedResource()
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        }
        accessedFolderURL = url
        BitChordSettings.shared.localMusicFolder = url.lastPathComponent
    }
    
    @discardableResult
    private func resolveCustomFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        _ = url.startAccessingSecurityScopedResource()
        accessedFolderURL = url
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        return url
    }
    
    // MARK: - Scanning
    
    /// Rescans all configured sources and returns the number of tracks found.
    @discardableResult
    public func scan() async -> Int {
        guard !isScanning else { return tracks.count }
        isScanning = true
        defer { isScanning = false }
        
        let settings = BitChordSettings.shared
        let filterNonMusic = settings.filterNonMusicAudio
        let includeAppleMusic = settings.includeAppleMusicLibrary
        
        var roots: [URL] = []
        if let custom = accessedFolderURL ?? resolveCustomFolder() {
            roots.append(custom)
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            roots.append(docs)
        }
        
        let artworkDir = Self.artworkDirectory()
        let fileTracks = await Task.detached(priority: .userInitiated) {
            await Self.scanFiles(roots: roots, filterNonMusic: filterNonMusic, artworkDir: artworkDir)
        }.value
        
        var result = fileTracks
        if includeAppleMusic {
            let libraryTracks = await scanMediaLibrary(filterNonMusic: filterNonMusic)
            let existing = Set(result.map { $0.id })
            result.append(contentsOf: libraryTracks.filter { !existing.contains($0.id) })
        }
        
        result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        tracks = result
        lastScanDate = Date()
        UserDefaults.standard.set(lastScanDate, forKey: Self.lastScanKey)
        Self.saveIndex(result)
        return result.count
    }
    
    nonisolated private static func scanFiles(roots: [URL], filterNonMusic: Bool, artworkDir: URL) async -> [Track] {
        var found: [Track] = []
        let fm = FileManager.default
        for root in roots {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            var urls: [URL] = []
            while let next = enumerator.nextObject() as? URL {
                let ext = next.pathExtension.lowercased()
                guard supportedExtensions.contains(ext) else { continue }
                if filterNonMusic {
                    let name = next.lastPathComponent.lowercased()
                    if ext == "wav" || name.contains("voice") || name.contains("recording") || name.contains("memo") { continue }
                }
                urls.append(next)
            }
            for url in urls {
                if let track = await makeTrack(from: url, filterNonMusic: filterNonMusic, artworkDir: artworkDir) {
                    found.append(track)
                }
            }
        }
        return found
    }
    
    nonisolated private static func makeTrack(from url: URL, filterNonMusic: Bool, artworkDir: URL) async -> Track? {
        let asset = AVURLAsset(url: url)
        let seconds: Double
        if let d = try? await asset.load(.duration) {
            seconds = d.seconds.isFinite ? d.seconds : 0
        } else {
            seconds = 0
        }
        if filterNonMusic && seconds > 0 && seconds < 30 { return nil }
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = ""
        var artworkURL: URL? = nil
        let id = "local_" + stableHash(url.path)
        
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let v = try? await item.load(.stringValue), !v.isEmpty { title = v }
                case .commonKeyArtist:
                    if let v = try? await item.load(.stringValue), !v.isEmpty { artist = v }
                case .commonKeyAlbumName:
                    if let v = try? await item.load(.stringValue), !v.isEmpty { album = v }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue), !data.isEmpty {
                        let artFile = artworkDir.appendingPathComponent("\(id).jpg")
                        if (try? data.write(to: artFile, options: .atomic)) != nil {
                            artworkURL = artFile
                        }
                    }
                default:
                    break
                }
            }
        }
        
        let ext = url.pathExtension.lowercased()
        let lossless = ["flac", "alac", "wav", "aiff", "aif"].contains(ext)
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: seconds,
            artworkURL: artworkURL,
            streamURL: url,
            isLossless: lossless
        )
    }
    
    private func scanMediaLibrary(filterNonMusic: Bool) async -> [Track] {
        #if canImport(MediaPlayer) && os(iOS)
        var status = MPMediaLibrary.authorizationStatus()
        if status == .notDetermined {
            status = await withCheckedContinuation { cont in
                MPMediaLibrary.requestAuthorization { cont.resume(returning: $0) }
            }
        }
        guard status == .authorized else { return [] }
        let items = MPMediaQuery.songs().items ?? []
        let artworkDir = Self.artworkDirectory()
        var result: [Track] = []
        for item in items {
            // DRM-protected / cloud-only items have no playable asset URL
            guard let assetURL = item.assetURL, !item.hasProtectedAsset else { continue }
            if filterNonMusic && item.playbackDuration < 30 { continue }
            let id = "local_ml_\(item.persistentID)"
            var artURL: URL? = nil
            if let image = item.artwork?.image(at: CGSize(width: 300, height: 300)),
               let data = image.jpegData(compressionQuality: 0.85) {
                let file = artworkDir.appendingPathComponent("\(id).jpg")
                if (try? data.write(to: file, options: .atomic)) != nil { artURL = file }
            }
            result.append(Track(
                id: id,
                title: item.title ?? "Unknown Title",
                artist: item.artist ?? "Unknown Artist",
                album: item.albumTitle ?? "",
                duration: item.playbackDuration,
                artworkURL: artURL,
                streamURL: assetURL
            ))
        }
        return result
        #else
        return []
        #endif
    }
    
    // MARK: - Persistence
    
    nonisolated private static func stableHash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
    
    nonisolated private static func artworkDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("LocalMusicArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private static func indexURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("local_music_index.json")
    }
    
    private static func saveIndex(_ tracks: [Track]) {
        if let data = try? JSONEncoder().encode(tracks) {
            try? data.write(to: indexURL(), options: .atomic)
        }
    }
    
    private static func loadIndex() -> [Track] {
        guard let data = try? Data(contentsOf: indexURL()),
              let list = try? JSONDecoder().decode([Track].self, from: data) else { return [] }
        // Drop files that no longer exist on disk
        return list.filter { track in
            guard let url = track.streamURL, url.isFileURL else { return true }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }
}
