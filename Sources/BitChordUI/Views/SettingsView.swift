import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var sleepTimer = SleepTimer.shared
    
    @State private var storageUsage: String = "Calculating..."
    @State private var storedCount: Int = 0
    @State private var showClearAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Lyrics Storage Section (Switchable Auto-Download)
                Section {
                    Toggle("Auto-Download to Storage", isOn: $settings.autoDownloadLyricsToStorage)
                        .tint(.red)
                    
                    HStack {
                        Text("Storage Consumed")
                        Spacer()
                        Text(storageUsage)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Offline Saved Tracks")
                        Spacer()
                        Text("\(storedCount) tracks")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("Clear Lyrics Storage", systemImage: "trash")
                    }
                } header: {
                    Label("Lyrics Storage & Offline", systemImage: "quote.bubble.fill")
                } footer: {
                    Text(settings.autoDownloadLyricsToStorage ?
                         "Auto-download is ON: All retrieved lyrics are automatically cached locally on your device for offline reading." :
                         "Auto-download is OFF: Lyrics are streamed transiently during active playback without consuming local device storage.")
                }
                
                // MARK: - Audio Quality & Output
                Section {
                    Picker("Streaming Quality", selection: $settings.audioQuality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    Toggle("Bit-Perfect USB DAC Mode", isOn: $settings.bitPerfectEnabled)
                        .tint(.red)
                    
                    Picker("Equalizer Preset", selection: $settings.equalizerPreset) {
                        ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                } header: {
                    Label("Audio Engine & DAC", systemImage: "hifispeaker.fill")
                } footer: {
                    Text("Bit-perfect bypasses system audio resampling when connected to an external USB DAC.")
                }
                
                // MARK: - Playback Transitions
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Crossfade")
                            Spacer()
                            Text(String(format: "%.1f s", settings.crossfadeSeconds))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.crossfadeSeconds, in: 0...12, step: 0.5)
                            .tint(.red)
                    }
                    
                    Toggle("Automix [Beta]", isOn: $settings.automixBetaEnabled)
                        .tint(.red)
                    
                    Toggle("Skip Silence", isOn: $settings.skipSilenceEnabled)
                        .tint(.red)
                    
                    Picker("Sleep Timer", selection: Binding(
                        get: { sleepTimer.isActive ? Int(sleepTimer.remainingSeconds / 60) : 0 },
                        set: { minutes in
                            if minutes > 0 {
                                sleepTimer.start(durationMinutes: minutes) {
                                    AudioPlayerEngine.shared.pause()
                                }
                            } else {
                                sleepTimer.stop()
                            }
                        }
                    )) {
                        Text("Off").tag(0)
                        Text("15 Minutes").tag(15)
                        Text("30 Minutes").tag(30)
                        Text("45 Minutes").tag(45)
                        Text("60 Minutes").tag(60)
                    }
                } header: {
                    Label("Playback & Transitions", systemImage: "slider.horizontal.3")
                }
                
                // MARK: - Scrobbling & Integrations
                Section {
                    Toggle("Last.fm Scrobbler", isOn: $settings.lastFmEnabled)
                        .tint(.red)
                    if settings.lastFmEnabled {
                        TextField("Last.fm Username", text: $settings.lastFmUsername)
                        SecureField("Session Key", text: $settings.lastFmSessionKey)
                    }
                    
                    Toggle("ListenBrainz", isOn: $settings.listenBrainzEnabled)
                        .tint(.red)
                    if settings.listenBrainzEnabled {
                        SecureField("User Token", text: $settings.listenBrainzToken)
                    }
                    
                    Toggle("Discord Rich Presence", isOn: $settings.discordRpcEnabled)
                        .tint(.red)
                } header: {
                    Label("Scrobbling & Social", systemImage: "arrow.triangle.2.circlepath")
                }
                
                // MARK: - About
                Section {
                    VStack(spacing: 12) {
                        BitChordLogoView(size: 72)
                        Text("BitChord for iOS")
                            .font(.title3.bold())
                        Text("High-fidelity lossless streaming client inspired by Apple Music.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (iOS)")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/rzrinanda/bitchord-ios")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About BitChord")
                }
            }
            .navigationTitle("Settings")
            .task {
                await refreshStorageStats()
            }
            .alert("Clear Lyrics Storage", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    Task {
                        await LyricsManager.shared.clearAllDownloadedLyrics()
                        await refreshStorageStats()
                    }
                }
            } message: {
                Text("This will delete all permanently cached lyrics files from your device. You can re-download them anytime.")
            }
        }
    }
    
    private func refreshStorageStats() async {
        storageUsage = await LyricsManager.shared.getStorageUsageString()
        storedCount = await LyricsManager.shared.getDownloadedLyricsCount()
    }
}
