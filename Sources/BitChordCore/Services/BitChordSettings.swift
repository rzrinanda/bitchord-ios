import Foundation
import SwiftUI
import Network

@MainActor
public final class BitChordSettings: ObservableObject {
    public static let shared = BitChordSettings()
    
    // Lyrics Storage Settings (Requested Feature)
    @AppStorage("BitChord.Lyrics.AutoDownloadToStorage") public var autoDownloadLyricsToStorage: Bool = true {
        didSet {
            Task {
                await LyricsManager.shared.setAutoDownloadLyrics(autoDownloadLyricsToStorage)
            }
        }
    }
    
    // Audio Playback & Quality Settings (Android Reference)
    @AppStorage("BitChord.Audio.Quality") public var audioQualityRaw: String = AudioQuality.lossless.rawValue
    @AppStorage("BitChord.Audio.DirectSourceStream") public var directSourceStream: Bool = true
    @AppStorage("BitChord.Audio.WifiQuality") public var wifiAudioQuality: String = "Lossless"
    @AppStorage("BitChord.Audio.CellularQuality") public var cellularAudioQuality: String = "Lossless"
    @AppStorage("BitChord.Audio.DolbyAtmos") public var dolbyAtmosEnabled: Bool = false
    @AppStorage("BitChord.Audio.BitPerfect") public var bitPerfectEnabled: Bool = false
    @AppStorage("BitChord.Audio.Crossfade") public var crossfadeSeconds: Double = 3.0
    @AppStorage("BitChord.Audio.Automix") public var automixBetaEnabled: Bool = false
    @AppStorage("BitChord.Audio.AutomixPerf") public var automixPerformance: String = "Balanced"
    @AppStorage("BitChord.Audio.SkipSilence") public var skipSilenceEnabled: Bool = false
    @AppStorage("BitChord.Audio.SpatialAudio") public var spatialAudioEnabled: Bool = false
    @AppStorage("BitChord.Audio.Equalizer") public var equalizerPresetRaw: String = EqualizerPreset.flat.rawValue
    
    // Downloads & Offline
    @AppStorage("BitChord.Download.Quality") public var downloadQuality: String = "Lossless"
    @AppStorage("BitChord.Download.WifiOnly") public var downloadWifiOnly: Bool = true
    @AppStorage("BitChord.Download.ExportCompatible") public var exportCompatibleDownloads: Bool = false
    @AppStorage("BitChord.Download.KeepUpdated") public var keepPlaylistsUpdated: Bool = false
    
    // Visuals & Appearance
    @AppStorage("BitChord.Appearance.Theme") public var themeMode: String = "Dark"
    @AppStorage("BitChord.Appearance.ReduceAnimation") public var reduceAnimation: Bool = false
    @AppStorage("BitChord.Appearance.ReduceDynamicBlur") public var reduceDynamicBlur: Bool = false
    @AppStorage("BitChord.Appearance.LiquidGlass") public var liquidGlassEnabled: Bool = false
    @AppStorage("BitChord.Appearance.LegacyMesh") public var legacyMeshGradient: Bool = false
    @AppStorage("BitChord.Appearance.AnimatedCover") public var animatedCoverArt: Bool = true
    @AppStorage("BitChord.Appearance.AnimatedCoverCellular") public var animatedCoverCellular: Bool = false
    @AppStorage("BitChord.Appearance.AppIcon") public var selectedAppIcon: String = "Default"
    
    // Lyrics Options
    @AppStorage("BitChord.Lyrics.Synced") public var syncedLyricsEnabled: Bool = true
    @AppStorage("BitChord.Lyrics.BlurUnfocused") public var blurUnfocusedLyrics: Bool = true
    @AppStorage("BitChord.Lyrics.ArtistSignatures") public var artistSignaturesEnabled: Bool = false
    
    // Sources & Streaming
    @AppStorage("BitChord.Source.JioSaavn") public var jiosaavnSourceEnabled: Bool = false
    
    // Addon Sources (Dynamic fallback sources e.g. SoundFean Qobuz)
    @Published public var addonSources: [AddonSource] = [] {
        didSet {
            saveAddonSources()
        }
    }
    
    // Storage & Cache
    @AppStorage("BitChord.Storage.ShowCachedFolder") public var showCachedSongsFolder: Bool = false
    @AppStorage("BitChord.Storage.CacheLimitMB") public var songCacheLimitMB: Double = 512.0
    
    // Advanced & Stats
    @AppStorage("BitChord.Advanced.StatsForNerds") public var statsForNerdsEnabled: Bool = false
    
    // Scrobbler & External Integrations
    @AppStorage("BitChord.LastFm.Enabled") public var lastFmEnabled: Bool = false
    @AppStorage("BitChord.LastFm.Username") public var lastFmUsername: String = ""
    @AppStorage("BitChord.LastFm.SessionKey") public var lastFmSessionKey: String = ""
    
    @AppStorage("BitChord.ListenBrainz.Enabled") public var listenBrainzEnabled: Bool = false
    @AppStorage("BitChord.ListenBrainz.Token") public var listenBrainzToken: String = ""
    
    @AppStorage("BitChord.Discord.Enabled") public var discordRpcEnabled: Bool = true
    
    // Spotify Integration
    @AppStorage("BitChord.Spotify.Connected") public var spotifyConnected: Bool = false
    @AppStorage("BitChord.Spotify.DisplayName") public var spotifyDisplayName: String = ""
    @AppStorage("BitChord.Spotify.Username") public var spotifyUsername: String = ""
    @AppStorage("BitChord.Spotify.AvatarURL") public var spotifyAvatarURL: String = ""
    @AppStorage("BitChord.Spotify.CookieSPDC") public var spotifyCookieSPDC: String = ""
    @AppStorage("BitChord.Spotify.AccessToken") public var spotifyAccessToken: String = ""
    
    public func setSpotifyAccount(displayName: String, username: String, avatarURL: String?, spdc: String, accessToken: String?) {
        self.spotifyDisplayName = displayName
        self.spotifyUsername = username
        self.spotifyAvatarURL = avatarURL ?? ""
        self.spotifyCookieSPDC = spdc
        self.spotifyAccessToken = accessToken ?? ""
        self.spotifyConnected = true
    }
    
    public func disconnectSpotify() {
        self.spotifyDisplayName = ""
        self.spotifyUsername = ""
        self.spotifyAvatarURL = ""
        self.spotifyCookieSPDC = ""
        self.spotifyAccessToken = ""
        self.spotifyConnected = false
    }
    
    public var audioQuality: AudioQuality {
        get { AudioQuality(rawValue: audioQualityRaw) ?? .lossless }
        set { audioQualityRaw = newValue.rawValue }
    }
    
    public var equalizerPreset: EqualizerPreset {
        get { EqualizerPreset(rawValue: equalizerPresetRaw) ?? .flat }
        set { equalizerPresetRaw = newValue.rawValue }
    }
    
    public init() {
        loadAddonSources()
    }
    
    public func addAddonSource(_ source: AddonSource) {
        if let idx = addonSources.firstIndex(where: { $0.id == source.id }) {
            addonSources[idx] = source
        } else {
            addonSources.append(source)
        }
    }
    
    public func removeAddonSource(id: String) {
        addonSources.removeAll(where: { $0.id == id })
    }
    
    public func toggleAddonSource(id: String) {
        if let idx = addonSources.firstIndex(where: { $0.id == id }) {
            addonSources[idx].isEnabled.toggle()
        }
    }
    
    private func saveAddonSources() {
        if let data = try? JSONEncoder().encode(addonSources) {
            UserDefaults.standard.set(data, forKey: "BitChord.Source.Addons")
        }
    }
    
    private func loadAddonSources() {
        if let data = UserDefaults.standard.data(forKey: "BitChord.Source.Addons"),
           let sources = try? JSONDecoder().decode([AddonSource].self, from: data) {
            self.addonSources = sources
        }
    }
}

// MARK: - Addon Source Model (SoundFean & BitPerfect Compatible)
public struct AddonSource: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var version: String
    public var manifestURL: String
    public var baseURL: String
    public var resources: [String]
    public var allowDownloads: Bool
    public var isEnabled: Bool
    public var addedAt: Date
    
    public init(
        id: String,
        name: String,
        version: String,
        manifestURL: String,
        baseURL: String,
        resources: [String] = [],
        allowDownloads: Bool = true,
        isEnabled: Bool = true,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.manifestURL = manifestURL
        self.baseURL = baseURL
        self.resources = resources
        self.allowDownloads = allowDownloads
        self.isEnabled = isEnabled
        self.addedAt = addedAt
    }
}

// MARK: - Addon Service
public actor AddonService {
    public static let shared = AddonService()
    
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 50
        self.session = URLSession(configuration: config)
    }
    
    /// Fetches and parses manifest from a user-supplied addon URL
    public func fetchManifest(from rawInput: String) async throws -> AddonSource {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLError(.badURL)
        }
        
        var effectiveURL = trimmed
        if !effectiveURL.lowercased().hasPrefix("http://") && !effectiveURL.lowercased().hasPrefix("https://") {
            effectiveURL = "https://" + effectiveURL
        }
        
        var manifestURLString = effectiveURL
        var baseURLString = effectiveURL
        
        if effectiveURL.lowercased().hasSuffix(".json") {
            manifestURLString = effectiveURL
            if let lastSlash = effectiveURL.lastIndex(of: "/") {
                baseURLString = String(effectiveURL[..<lastSlash])
            }
        } else {
            if baseURLString.hasSuffix("/") {
                baseURLString.removeLast()
            }
            manifestURLString = baseURLString + "/manifest.json"
        }
        
        guard let url = URL(string: manifestURLString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        
        let id = (json["id"] as? String) ?? UUID().uuidString
        let name = (json["name"] as? String) ?? (url.host ?? "Custom Addon")
        let version = (json["version"] as? String) ?? "1.0.0"
        let resources = (json["resources"] as? [String]) ?? []
        let allowDownloads: Bool
        if let d = json["allowDownloads"] as? Int {
            allowDownloads = d == 1
        } else if let b = json["allowDownloads"] as? Bool {
            allowDownloads = b
        } else {
            allowDownloads = true
        }
        
        return AddonSource(
            id: id,
            name: name,
            version: version,
            manifestURL: manifestURLString,
            baseURL: baseURLString,
            resources: resources,
            allowDownloads: allowDownloads,
            isEnabled: true
        )
    }
    
    /// Attempts to resolve direct stream via configured addon
    public func resolveStream(trackTitle: String, artist: String?, addon: AddonSource) async -> StreamInfo? {
        guard addon.isEnabled, addon.resources.contains("stream") else { return nil }
        
        let query = "\(trackTitle) \(artist ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "\(addon.baseURL)/search?q=\(encodedQuery)") else {
            return nil
        }
        
        var searchReq = URLRequest(url: searchURL)
        searchReq.timeoutInterval = 8.0
        
        guard let (data, resp) = try? await session.data(for: searchReq),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [[String: Any]],
              let first = tracks.first,
              let trackId = (first["id"] as? String) ?? (first["id"] as? Int).map(String.init) else {
            return nil
        }
        
        guard let streamURL = URL(string: "\(addon.baseURL)/stream/\(trackId)") else { return nil }
        var streamReq = URLRequest(url: streamURL)
        streamReq.timeoutInterval = 8.0
        
        guard let (streamData, sResp) = try? await session.data(for: streamReq),
              let sHttp = sResp as? HTTPURLResponse, sHttp.statusCode == 200,
              let streamJson = try? JSONSerialization.jsonObject(with: streamData) as? [String: Any],
              let directURLString = streamJson["url"] as? String,
              let directURL = URL(string: directURLString) else {
            return nil
        }
        
        let sampleRate = (streamJson["sampleRate"] as? Double) ?? Double((streamJson["sampleRate"] as? Int) ?? 44100)
        let isLossless = (streamJson["format"] as? String)?.lowercased() == "flac" || (streamJson["quality"] as? String)?.contains("FLAC") == true
        
        return StreamInfo(
            streamURL: directURL,
            format: (streamJson["format"] as? String) ?? "flac",
            bitrate: 1411,
            isLossless: isLossless,
            sampleRate: sampleRate
        )
    }
}

// MARK: - Network Monitor (Detects Wi-Fi vs Cellular for Audio Quality Settings)
@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public var isWifi: Bool = true
    @Published public var isCellular: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "BitChord.NetworkMonitor")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let onCellular = path.usesInterfaceType(.cellular)
                let onWifi = path.usesInterfaceType(.wifi) || (!onCellular && path.status == .satisfied)
                self.isCellular = onCellular
                self.isWifi = onWifi
            }
        }
        monitor.start(queue: queue)
    }
}
