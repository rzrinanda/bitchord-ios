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
    
    // Audio Playback Settings
    @AppStorage("BitChord.Audio.Quality") public var audioQualityRaw: String = AudioQuality.lossless.rawValue
    @AppStorage("BitChord.Audio.BitPerfect") public var bitPerfectEnabled: Bool = false
    @AppStorage("BitChord.Audio.Crossfade") public var crossfadeSeconds: Double = 3.0
    @AppStorage("BitChord.Audio.Automix") public var automixBetaEnabled: Bool = false
    @AppStorage("BitChord.Audio.SkipSilence") public var skipSilenceEnabled: Bool = false
    @AppStorage("BitChord.Audio.Equalizer") public var equalizerPresetRaw: String = EqualizerPreset.flat.rawValue
    
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
