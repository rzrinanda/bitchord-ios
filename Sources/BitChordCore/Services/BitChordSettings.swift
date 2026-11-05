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
    @AppStorage("BitChord.Audio.OutputPrecision") public var outputPrecision: String = "16-bit PCM"
    @AppStorage("BitChord.Audio.PreferUSBDAC") public var preferUSBDAC: Bool = false
    @AppStorage("BitChord.Audio.LoudnessNormalization") public var loudnessNormalization: Bool = true
    @AppStorage("BitChord.Audio.DisableOnPhoneSpeaker") public var disableOnPhoneSpeaker: Bool = true
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
    @AppStorage("BitChord.Appearance.Font") public var selectedFont: String = "Default"
    @AppStorage("BitChord.Appearance.ReduceAnimation") public var reduceAnimation: Bool = false
    @AppStorage("BitChord.Appearance.ReduceDynamicBlur") public var reduceDynamicBlur: Bool = false
    @AppStorage("BitChord.Appearance.LiquidGlass") public var liquidGlassEnabled: Bool = false
    @AppStorage("BitChord.Appearance.LegacyMesh") public var legacyMeshGradient: Bool = false
    @AppStorage("BitChord.Appearance.AnimatedCover") public var animatedCoverArt: Bool = true
    @AppStorage("BitChord.Appearance.AnimatedCoverCellular") public var animatedCoverCellular: Bool = false
    @AppStorage("BitChord.Appearance.SpotifyCanvas") public var spotifyCanvasEnabled: Bool = true
    @AppStorage("BitChord.Appearance.AppIcon") public var selectedAppIcon: String = "Default"
    
    // Performance
    @AppStorage("BitChord.Performance.HighPerformanceMode") public var highPerformanceMode: Bool = true
    @AppStorage("BitChord.Performance.RefreshRate") public var targetRefreshRate: String = "60 Hz"
    @AppStorage("BitChord.Performance.RenderQuality") public var renderQuality: String = "Balanced"
    
    // Lyrics Options
    @AppStorage("BitChord.Lyrics.ShowFullLyrics") public var showFullLyrics: Bool = false
    @AppStorage("BitChord.Lyrics.ShowBilingual") public var showBilingualLyrics: Bool = false
    @AppStorage("BitChord.Lyrics.Synced") public var syncedLyricsEnabled: Bool = true
    @AppStorage("BitChord.Lyrics.BlurUnfocused") public var blurUnfocusedLyrics: Bool = true
    @AppStorage("BitChord.Lyrics.ArtistSignatures") public var artistSignaturesEnabled: Bool = false
    @AppStorage("BitChord.Lyrics.TranslationLanguage") public var translationLanguage: String = "Follows the app language"
    @AppStorage("BitChord.Lyrics.ActiveSource") public var activeLyricSourceId: String = "betterlyrics_portato"
    @AppStorage("BitChord.Lyrics.SourcesJSON") public var lyricSourcesJSON: String = ""
    
    // Local Music
    @AppStorage("BitChord.LocalMusic.FilterNonMusic") public var filterNonMusicAudio: Bool = true
    @AppStorage("BitChord.LocalMusic.SelectedFolder") public var localMusicFolder: String = "All audio folders"
    @AppStorage("BitChord.LocalMusic.IncludeAppleMusic") public var includeAppleMusicLibrary: Bool = true
    
    // Miscellaneous & Player Options
    @AppStorage("BitChord.Misc.ShowListenTogetherButton") public var showListenTogetherButton: Bool = false
    @AppStorage("BitChord.Misc.HideStatusBarInPlayer") public var hideStatusBarInPlayer: Bool = false
    @AppStorage("BitChord.Misc.ShowQueueHistory") public var showQueueHistory: Bool = false
    @AppStorage("BitChord.Misc.HideSongStatus") public var hideSongStatus: Bool = false
    @AppStorage("BitChord.Misc.PlayNextOnSwipe") public var playNextOnSwipe: Bool = false
    @AppStorage("BitChord.Misc.DontRepeatInSession") public var dontRepeatInCurrentSession: Bool = false
    @AppStorage("BitChord.Misc.StopOnCloseRecents") public var stopMusicOnCloseFromRecents: Bool = true
    @AppStorage("BitChord.Misc.HideVolumeSlider") public var hideVolumeSlider: Bool = false
    @AppStorage("BitChord.Misc.SmartAudioAlignment") public var smartAudioAlignment: Bool = true
    @AppStorage("BitChord.Misc.WorkOutGenres") public var workOutGenresLastFm: Bool = true
    @AppStorage("BitChord.Misc.AppLanguage") public var appLanguage: String = "System Default"
    
    // Sources & Streaming
    @AppStorage("BitChord.Source.JioSaavn") public var jiosaavnSourceEnabled: Bool = false
    
    // High-Speed Streaming Backend Server
    @AppStorage("BitChord.Backend.ServerURL") public var backendServerURL: String = "http://localhost:3000"
    @AppStorage("BitChord.Backend.UseBackendServer") public var useBackendServer: Bool = true
    @Published public var isBackendServerReachable: Bool = false
    
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
    
    public static let defaultLyricSources: [LyricSourceItem] = [
        LyricSourceItem(id: "betterlyrics_portato", name: "BetterLyrics Portato", subtitle: "QQ Music karaoke timings through Portato", isEnabled: true),
        LyricSourceItem(id: "paxsenix", name: "PaxSenix", subtitle: "Apple Music timings through the original PaxSenix API", isEnabled: true),
        LyricSourceItem(id: "paxsenix_spotify", name: "PaxSenix: Spotify", subtitle: "Spotify lyrics with PaxSenix fallback; synced timestamps", isEnabled: true),
        LyricSourceItem(id: "paxsenix_musixmatch", name: "PaxSenix: Musixmatch", subtitle: "Musixmatch timings with PaxSenix fallback", isEnabled: true),
        LyricSourceItem(id: "lyricsplus", name: "LyricsPlus", subtitle: "Syllable by syllable, on community database", isEnabled: true),
        LyricSourceItem(id: "unison", name: "Unison", subtitle: "Contributed by listeners, so it has what's new", isEnabled: true),
        LyricSourceItem(id: "yt_captions", name: "YouTube captions", subtitle: "Timed captions matched to the exact video", isEnabled: true),
        LyricSourceItem(id: "yt_music", name: "YouTube Music", subtitle: "Plain lyrics from the playing video's description", isEnabled: true),
        LyricSourceItem(id: "kugou", name: "KuGou", subtitle: "Whole lines, strong outside the English repertoire", isEnabled: true),
        LyricSourceItem(id: "lrclib", name: "LRCLIB", subtitle: "Whole lines only, and always up", isEnabled: true),
        LyricSourceItem(id: "musixmatch", name: "Musixmatch", subtitle: "Whole lines, from the biggest lyrics catalog", isEnabled: true),
        LyricSourceItem(id: "genius", name: "Genius", subtitle: "Plain text fallback, massive web catalog & crowd notes", isEnabled: true)
    ]
    
    public func getLyricSources() -> [LyricSourceItem] {
        guard !lyricSourcesJSON.isEmpty,
              let data = lyricSourcesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([LyricSourceItem].self, from: data),
              !list.isEmpty else {
            return Self.defaultLyricSources
        }
        return list
    }
    
    public func saveLyricSources(_ sources: [LyricSourceItem]) {
        if let data = try? JSONEncoder().encode(sources),
           let str = String(data: data, encoding: .utf8) {
            self.lyricSourcesJSON = str
        }
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
        Task {
            await checkBackendHealth()
        }
    }
    
    public func checkBackendHealth() async {
        guard useBackendServer else {
            self.isBackendServerReachable = false
            return
        }
        let trimmed = backendServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed.hasSuffix("/") ? "\(trimmed)health" : "\(trimmed)/health") else {
            self.isBackendServerReachable = false
            return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200 {
            self.isBackendServerReachable = true
        } else {
            self.isBackendServerReachable = false
        }
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

// MARK: - Lyric Source Item Model
public struct LyricSourceItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var isEnabled: Bool
    
    public init(id: String, name: String, subtitle: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.isEnabled = isEnabled
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
    public func resolveStream(
        trackTitle: String,
        artist: String?,
        album: String? = nil,
        duration: TimeInterval? = nil,
        addon: AddonSource
    ) async -> StreamInfo? {
        return await resolveStreamTiers(
            trackTitle: trackTitle,
            artist: artist,
            album: album,
            duration: duration,
            addon: addon
        ).first
    }
    
    /// Resolves ranked stream quality tiers for the exact requested track and version from a configured addon
    public func resolveStreamTiers(
        trackTitle: String,
        artist: String?,
        album: String? = nil,
        duration: TimeInterval? = nil,
        addon: AddonSource
    ) async -> [StreamInfo] {
        guard addon.isEnabled, addon.resources.contains("stream") else { return [] }
        
        let query = "\(trackTitle) \(artist ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "\(addon.baseURL)/search?q=\(encodedQuery)") else {
            return []
        }
        
        var searchReq = URLRequest(url: searchURL)
        searchReq.timeoutInterval = 8.0
        
        guard let (data, resp) = try? await session.data(for: searchReq),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [[String: Any]] else {
            return []
        }
        
        // Strictly match exact track title, artist, and version (never substitute Live/Acoustic/Remix/Cover for Studio or vice versa)
        var bestCandidate: [String: Any]? = nil
        var bestScore: Double = -1
        for item in tracks {
            if let isSample = item["sample"] as? Bool, isSample { continue }
            let dur = (item["duration"] as? Double) ?? (item["duration"] as? Int).map(Double.init)
            if let d = dur, d > 0 && d < 60 { continue }
            
            let candTitle = (item["title"] as? String) ?? (item["name"] as? String) ?? ""
            let candArtist: String
            if let a = item["artist"] as? String {
                candArtist = a
            } else if let aDict = item["artist"] as? [String: Any], let aName = aDict["name"] as? String {
                candArtist = aName
            } else if let performer = item["performer"] as? [String: Any], let pName = performer["name"] as? String {
                candArtist = pName
            } else {
                candArtist = artist ?? ""
            }
            let candAlbum: String?
            if let alb = item["album"] as? String {
                candAlbum = alb
            } else if let albDict = item["album"] as? [String: Any], let albTitle = albDict["title"] as? String {
                candAlbum = albTitle
            } else {
                candAlbum = nil
            }
            let versionTag = item["version"] as? String
            let fullCandTitle = versionTag != nil && !versionTag!.isEmpty ? "\(candTitle) (\(versionTag!))" : candTitle
            
            if let score = TrackVersionMatcher.matchScore(
                requestedTitle: trackTitle,
                requestedArtist: artist ?? "",
                requestedAlbum: album,
                requestedDuration: duration,
                candidateTitle: fullCandTitle,
                candidateArtist: candArtist,
                candidateAlbum: candAlbum,
                candidateSubtitle: versionTag,
                candidateDuration: dur
            ) {
                if score > bestScore {
                    bestScore = score
                    bestCandidate = item
                }
            }
        }
        
        guard let chosen = bestCandidate,
              let trackId = (chosen["id"] as? String) ?? (chosen["id"] as? Int).map(String.init) else {
            return []
        }
        
        guard let streamURL = URL(string: "\(addon.baseURL)/stream/\(trackId)") else { return [] }
        var streamReq = URLRequest(url: streamURL)
        streamReq.timeoutInterval = 8.0
        
        guard let (streamData, sResp) = try? await session.data(for: streamReq),
              let sHttp = sResp as? HTTPURLResponse, sHttp.statusCode == 200,
              let streamJson = try? JSONSerialization.jsonObject(with: streamData) as? [String: Any] else {
            return []
        }
        
        // Reject any 30-second sample/preview stream
        if let isSample = (streamJson["sample"] as? Bool) ?? (streamJson["isSample"] as? Bool), isSample {
            return []
        }
        if let streamDur = (streamJson["duration"] as? Double) ?? (streamJson["duration"] as? Int).map(Double.init), streamDur > 0 && streamDur < 60 {
            return []
        }
        
        var tiers: [StreamInfo] = []
        if let streamsArray = streamJson["streams"] as? [[String: Any]] {
            for s in streamsArray {
                guard let uStr = s["url"] as? String,
                      !uStr.lowercased().contains("sample"),
                      !uStr.lowercased().contains("preview"),
                      let u = URL(string: uStr) else { continue }
                let fmt = (s["format"] as? String) ?? (s["mimeType"] as? String) ?? "flac"
                let sr = (s["sampleRate"] as? Double) ?? Double((s["sampleRate"] as? Int) ?? 44100)
                let codec = StreamInfo.detectCodec(from: fmt, explicitCodec: s["codec"] as? String)
                let genuineLossless = StreamInfo.evaluateGenuineLossless(format: fmt, codec: codec, claimedLossless: true)
                let depth = genuineLossless ? ((s["bitDepth"] as? Int) ?? (sr > 48000 ? 24 : 16)) : nil
                let br = (s["bitrate"] as? Int) ?? (genuineLossless ? (sr > 48000 ? 4608 : 1411) : 320)
                tiers.append(
                    StreamInfo(
                        streamURL: u,
                        format: fmt,
                        codec: codec,
                        bitrate: br,
                        isLossless: genuineLossless,
                        sampleRate: sr,
                        bitDepth: depth,
                        sourceId: "addon_\(addon.id)",
                        sourceIsDirect: true
                    )
                )
            }
        }
        
        if let directURLString = streamJson["url"] as? String,
           let directURL = URL(string: directURLString) {
            let lowerURL = directURLString.lowercased()
            if !lowerURL.contains("sample") && !lowerURL.contains("preview") && !lowerURL.contains("teaser") {
                let fmt = (streamJson["format"] as? String) ?? (streamJson["mimeType"] as? String) ?? "flac"
                let codec = StreamInfo.detectCodec(from: fmt, explicitCodec: streamJson["codec"] as? String)
                let sampleRate = (streamJson["sampleRate"] as? Double) ?? Double((streamJson["sampleRate"] as? Int) ?? 44100)
                let claimed = (streamJson["format"] as? String)?.lowercased().contains("flac") == true
                    || (streamJson["quality"] as? String)?.uppercased().contains("FLAC") == true
                    || (streamJson["format"] as? String)?.lowercased().contains("alac") == true
                let isLossless = StreamInfo.evaluateGenuineLossless(format: fmt, codec: codec, claimedLossless: claimed)
                let bitDepth = isLossless ? ((streamJson["bitDepth"] as? Int) ?? (sampleRate > 48000 ? 24 : 16)) : nil
                let bitrate = (streamJson["bitrate"] as? Int) ?? (isLossless ? (sampleRate > 48000 ? 4608 : 1411) : 320)
                
                tiers.append(
                    StreamInfo(
                        streamURL: directURL,
                        format: fmt,
                        codec: codec,
                        bitrate: bitrate,
                        isLossless: isLossless,
                        sampleRate: sampleRate,
                        bitDepth: bitDepth,
                        sourceId: "addon_\(addon.id)",
                        sourceIsDirect: true
                    )
                )
            }
        }
        
        return StreamInfo.selectTopDistinctQualityLevels(from: tiers, maxLevels: 3)
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
                // Strictly mutually exclusive: if Wi-Fi or Ethernet is active, Wi-Fi is IN USE and Cellular is NOT.
                if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                    self.isWifi = true
                    self.isCellular = false
                } else if path.usesInterfaceType(.cellular) {
                    self.isWifi = false
                    self.isCellular = true
                } else {
                    self.isWifi = true
                    self.isCellular = false
                }
            }
        }
        monitor.start(queue: queue)
    }
}
