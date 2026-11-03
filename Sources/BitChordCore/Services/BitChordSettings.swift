import Foundation
import SwiftUI

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
    
    public var audioQuality: AudioQuality {
        get { AudioQuality(rawValue: audioQualityRaw) ?? .lossless }
        set { audioQualityRaw = newValue.rawValue }
    }
    
    public var equalizerPreset: EqualizerPreset {
        get { EqualizerPreset(rawValue: equalizerPresetRaw) ?? .flat }
        set { equalizerPresetRaw = newValue.rawValue }
    }
    
    public init() {}
}
