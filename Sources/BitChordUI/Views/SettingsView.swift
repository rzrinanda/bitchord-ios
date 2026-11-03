import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var sleepTimer = SleepTimer.shared
    
    @State private var searchText: String = ""
    @State private var showingGoogleLogin: Bool = false
    @State private var storageUsage: String = "18.4 MB"
    @State private var storedCount: Int = 12
    @State private var showClearAlert: Bool = false
    @State private var clearAlertType: String = ""
    
    public init() {}
    
    private var accountSubtitle: String {
        if accountManager.activeAccount.isGoogleAccount {
            return "Signed in: \(accountManager.activeAccount.displayName)"
        } else {
            return "Signed in: Guest Account"
        }
    }
    
    public var body: some View {
        NavigationStack {
            List {
                searchSection
                accountSection
                audioQualitySection
                navigationHubSection
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingGoogleLogin) {
                GoogleLoginSheet()
            }
            .alert(clearAlertType.isEmpty ? "Clear Lyrics Storage?" : "Clear \(clearAlertType)?", isPresented: $showClearAlert) {
                Button("Clear", role: .destructive) {
                    LyricsStorageManager.shared.clearAllDiskStorage()
                    storageUsage = LyricsStorageManager.shared.formattedStorageSize()
                    storedCount = 0
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently free device storage space.")
            }
            .task {
                calculateStorage()
            }
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search settings", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white.opacity(0.08))
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section {
            NavigationLink {
                AccountIntegrationsDetailView(showingGoogleLogin: $showingGoogleLogin)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Account & integrations")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(accountSubtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            
            NavigationLink {
                ListenTogetherDetailView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.2")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Listen together")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Share a code and play the same music, in time")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listRowBackground(Color.white.opacity(0.06))
    }
    
    @ViewBuilder
    private var audioQualitySection: some View {
        Section {
            NavigationLink {
                AudioSourcesDetailView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sources")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Where audio comes from and the order used")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Toggle(isOn: $settings.directSourceStream) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Direct Source Stream")
                        .font(.system(size: 15, weight: .medium))
                    Text("Bypass transcoder and play native stream directly")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .tint(.cyan)
            
            Picker(selection: $settings.wifiAudioQuality) {
                Text("Lossless (24-bit/48kHz)").tag("Lossless")
                Text("High (320 kbps)").tag("High")
                Text("Normal (160 kbps)").tag("Normal")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wifi")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 28)
                    Text("On Wi-Fi")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            
            Picker(selection: $settings.cellularAudioQuality) {
                Text("Lossless (24-bit/48kHz)").tag("Lossless")
                Text("High (320 kbps)").tag("High")
                Text("Normal (160 kbps)").tag("Normal")
                Text("Data Saver (96 kbps)").tag("Data Saver")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .frame(width: 28)
                    Text("On mobile data")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            
            Toggle(isOn: $settings.dolbyAtmosEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dolby Atmos")
                        .font(.system(size: 15, weight: .medium))
                    Text("Spatial binaural render when available")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .tint(.cyan)
        } header: {
            Text("AUDIO QUALITY")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.white.opacity(0.06))
    }
    
    @ViewBuilder
    private var navigationHubSection: some View {
        Section {
            NavigationLink {
                DownloadsDetailView()
            } label: {
                SettingsRowLabel(icon: "arrow.down.circle", color: .cyan, title: "Downloads")
            }
            
            NavigationLink {
                PlaybackDetailView()
            } label: {
                SettingsRowLabel(icon: "play.circle", color: .pink, title: "Playback")
            }
            
            NavigationLink {
                AppearanceDetailView()
            } label: {
                SettingsRowLabel(icon: "paintbrush", color: .yellow, title: "Appearance")
            }
            
            NavigationLink {
                LyricsDetailView(
                    storageUsage: $storageUsage,
                    storedCount: $storedCount,
                    showClearAlert: $showClearAlert
                )
            } label: {
                SettingsRowLabel(icon: "quote.bubble", color: .teal, title: "Lyrics")
            }
            
            NavigationLink {
                StorageDetailView(
                    storageUsage: $storageUsage,
                    showClearAlert: $showClearAlert,
                    clearAlertType: $clearAlertType
                )
            } label: {
                SettingsRowLabel(icon: "externaldrive", color: .blue, title: "Storage")
            }
            
            NavigationLink {
                LocalMusicDetailView()
            } label: {
                SettingsRowLabel(icon: "house.and.flag", color: .green, title: "Local Music")
            }
            
            NavigationLink {
                YourDataDetailView()
            } label: {
                SettingsRowLabel(icon: "shippingbox", color: .brown, title: "Your data")
            }
            
            NavigationLink {
                MiscellaneousDetailView()
            } label: {
                SettingsRowLabel(icon: "ellipsis.circle", color: .gray, title: "Miscellaneous")
            }
        }
        .listRowBackground(Color.white.opacity(0.06))
    }
    
    private func calculateStorage() {
        storageUsage = LyricsStorageManager.shared.formattedStorageSize()
        storedCount = LyricsStorageManager.shared.countStoredTracks()
    }
}

// MARK: - Reusable Row Label
private struct SettingsRowLabel: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 1. Account & Integrations Detail View (Photos 01, 02, 04)
private struct AccountIntegrationsDetailView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var settings = BitChordSettings.shared
    @Binding var showingGoogleLogin: Bool
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.cyan.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(accountManager.activeAccount.avatarLetter)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(accountManager.activeAccount.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        Text("YouTube Music account")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.secondary)
                    Text("Listen as")
                    Spacer()
                    Text(accountManager.activeAccount.handle)
                        .foregroundColor(.secondary)
                }
                
                Button(role: .destructive) {
                    accountManager.removeAccount(accountManager.activeAccount)
                } label: {
                    Text("Sign out")
                }
            } header: {
                Text("ACCOUNT")
            } footer: {
                Text("A Google account can have Personal and Brand profiles. Each has its own library, likes and history.")
            }
            
            Section {
                Button {
                    // Spotify link action
                } label: {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spotify")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Tap to connect")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("SPOTIFY")
            } footer: {
                Text("Sign in to load your playlists. Playback uses YouTube Music.")
            }
            
            Section {
                Toggle(isOn: $settings.discordRpcEnabled) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Discord")
                                .font(.system(size: 15, weight: .medium))
                            Text("Show what you are playing on your Discord profile")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.cyan)
            } header: {
                Text("RICH PRESENCE")
            }
            
            Section {
                Toggle(isOn: $settings.listenBrainzEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ListenBrainz")
                            .font(.system(size: 15, weight: .medium))
                        Text(settings.listenBrainzToken.isEmpty ? "Enter a token to enable" : "Connected")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
                
                Toggle(isOn: $settings.lastFmEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last.fm")
                            .font(.system(size: 15, weight: .medium))
                        Text(settings.lastFmUsername.isEmpty ? "Tap to sign in" : "Signed in as \(settings.lastFmUsername)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
            } header: {
                Text("SCROBBLING")
            } footer: {
                Text("Scrobble your listens to Last.fm and ListenBrainz.")
            }
        }
        .navigationTitle("Account & integrations")
    }
}

// MARK: - 2. Sources Detail View (Photos 03, 08)
private struct AudioSourcesDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @State private var showingAddAddonSheet: Bool = false
    
    var body: some View {
        Form {
            Section {
                // Dynamically list user-added addons first
                ForEach(Array(settings.addonSources.enumerated()), id: \.element.id) { index, addon in
                    HStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { addon.isEnabled },
                            set: { _ in settings.toggleAddonSource(id: addon.id) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(addon.name)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                Text("v\(addon.version) • \(addon.resources.map { $0.capitalized }.joined(separator: ", "))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.cyan)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            settings.removeAddonSource(id: addon.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                // JioSaavn
                Toggle(isOn: $settings.jiosaavnSourceEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(settings.addonSources.count + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("JioSaavn")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text("May match the wrong version of a song. Enable at your own risk.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
                
                // YouTube Music
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(settings.addonSources.count + 2)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("YouTube Music")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text("Lossy • Full catalogue • Radio")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Always on")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Add an addon button
                Button {
                    showingAddAddonSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add an addon")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Point BitChord at an addon server you host or were given a link to")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("SOURCES, TRIED IN THIS ORDER")
            } footer: {
                Text("If a source does not have a track or cannot be reached, BitChord tries the next one. Sources above YouTube can replace its recording when they return a better version.")
            }
            
            Section {
                NavigationLink("WebDAV Server Setup") {
                    Text("WebDAV configuration")
                }
            } header: {
                Text("WEBDAV")
            }
        }
        .navigationTitle("Sources")
        .sheet(isPresented: $showingAddAddonSheet) {
            AddAddonSheet()
        }
    }
}

// MARK: - Add Addon Sheet
private struct AddAddonSheet: View {
    @ObservedObject var settings = BitChordSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var urlInput: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var fetchedAddon: AddonSource? = nil
    @State private var hasAdded: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Addon Server")
                            .font(.headline)
                        Text("Point BitChord at an addon server you host or were given a link to. Compatible with SoundFean and BitPerfect manifest URLs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        TextField("https://...", text: $urlInput)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !urlInput.isEmpty {
                            Button {
                                urlInput = ""
                                errorMessage = nil
                                fetchedAddon = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        #if canImport(UIKit)
                        Button {
                            if let paste = UIPasteboard.general.string {
                                urlInput = paste.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                    
                    Button {
                        urlInput = "https://soundfean-musics.onrender.com/a/manifest.json"
                        errorMessage = nil
                        fetchedAddon = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("Sample: SoundFean Qobuz [Heisenbergg]")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                    }
                }
                
                if isConnecting {
                    Section {
                        HStack(spacing: 14) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connecting to Addon Server...")
                                    .font(.subheadline.bold())
                                Text("Render / free-tier servers may take 15–30s to wake up if sleeping.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Connection Failed")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.red)
                            }
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if let addon = fetchedAddon {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(addon.name)
                                        .font(.headline)
                                    Text("v\(addon.version) • \(addon.id)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                if addon.resources.contains("stream") {
                                    Label("Hi-Res Stream", systemImage: "waveform")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.15))
                                        .clipShape(Capsule())
                                        .foregroundColor(.cyan)
                                }
                                if addon.resources.contains("search") {
                                    Label("Catalog Search", systemImage: "magnifyingglass")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.15))
                                        .clipShape(Capsule())
                                        .foregroundColor(.purple)
                                }
                                if addon.allowDownloads {
                                    Label("Downloads", systemImage: "arrow.down.circle")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Button {
                                settings.addAddonSource(addon)
                                hasAdded = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if hasAdded {
                                        Image(systemName: "checkmark")
                                        Text("Added to Sources")
                                    } else {
                                        Text("Save & Enable Addon")
                                    }
                                    Spacer()
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("VERIFIED ADDON")
                    }
                }
                
                Section {
                    Button {
                        connectAddon()
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                Text("Connecting...")
                            } else {
                                Text("Connect")
                            }
                            Spacer()
                        }
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                }
            }
            .navigationTitle("Add Addon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func connectAddon() {
        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isConnecting = true
        errorMessage = nil
        fetchedAddon = nil
        
        Task {
            do {
                let addon = try await AddonService.shared.fetchManifest(from: urlInput)
                await MainActor.run {
                    self.fetchedAddon = addon
                    self.isConnecting = false
                }
            } catch {
                await MainActor.run {
                    self.isConnecting = false
                    self.errorMessage = "Could not fetch manifest: \(error.localizedDescription). Please verify URL or wait if server is waking up."
                }
            }
        }
    }
}

// MARK: - 3. Downloads Detail View (Photos 05, 06)
private struct DownloadsDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    var body: some View {
        Form {
            Section {
                Picker("Download quality", selection: $settings.downloadQuality) {
                    Text("Lossless (~35 MB per track)").tag("Lossless")
                    Text("High (~8 MB per track)").tag("High")
                    Text("Normal (~4 MB per track)").tag("Normal")
                }
                
                Toggle("Download over Wi-Fi only", isOn: $settings.downloadWifiOnly)
                    .tint(.cyan)
                
                Toggle("Export compatible downloads", isOn: $settings.exportCompatibleDownloads)
                    .tint(.cyan)
                
                Toggle("Keep playlists updated", isOn: $settings.keepPlaylistsUpdated)
                    .tint(.cyan)
            } footer: {
                Text("Checks twice a day and downloads songs newly added to your downloaded playlists.")
            }
        }
        .navigationTitle("Downloads")
    }
}

// MARK: - 4. Playback Detail View (Photo 07)
private struct PlaybackDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var engine = AudioPlayerEngine.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.automixBetaEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automix [BETA]")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Times and blends transitions automatically, without a slider. Performance may vary on slower devices.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
                
                Picker("Automix performance", selection: $settings.automixPerformance) {
                    Text("Balanced").tag("Balanced")
                    Text("Quality").tag("Quality")
                    Text("Battery Saver").tag("Battery Saver")
                }
                
                Toggle(isOn: $settings.skipSilenceEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip silence")
                            .font(.system(size: 15, weight: .medium))
                        Text("Trim gaps longer than a second")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
                
                Toggle(isOn: $settings.spatialAudioEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spatial audio")
                            .font(.system(size: 15, weight: .medium))
                        Text("Widens stereo image for a more immersive feel")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
            }
            
            Section {
                Picker("Equalizer Preset", selection: $settings.equalizerPreset) {
                    ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue.capitalized).tag(preset)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Crossfade Duration")
                        Spacer()
                        Text(settings.crossfadeSeconds == 0 ? "Off" : "\(Int(settings.crossfadeSeconds))s")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.crossfadeSeconds, in: 0...12, step: 1)
                        .tint(.cyan)
                }
            } header: {
                Text("EQUALIZER & TRANSITIONS")
            }
        }
        .navigationTitle("Playback")
    }
}

// MARK: - 5. Appearance Detail View (Photos 20, 24, 33)
private struct AppearanceDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    let icons = ["Default", "Monochrome", "Liquid Glass", "Liquid Glass Dark", "Liquid Glass Clear", "Liquid Glass Clear Dark"]
    
    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $settings.themeMode) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("THEME")
            }
            
            Section {
                HStack {
                    Text("Font")
                    Spacer()
                    Text("SF Pro Display • Apple Music weights")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Toggle("Reduce animation", isOn: $settings.reduceAnimation)
                    .tint(.cyan)
                
                Toggle("Reduce dynamic blur", isOn: $settings.reduceDynamicBlur)
                    .tint(.cyan)
                
                Toggle("Liquid Glass", isOn: $settings.liquidGlassEnabled)
                    .tint(.cyan)
                
                Toggle("Legacy mesh gradient", isOn: $settings.legacyMeshGradient)
                    .tint(.cyan)
                
                Toggle("Animated cover art", isOn: $settings.animatedCoverArt)
                    .tint(.cyan)
                
                Toggle("Play animated cover over cellular", isOn: $settings.animatedCoverCellular)
                    .tint(.cyan)
            } header: {
                Text("VISUAL EFFECTS")
            }
            
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(icons, id: \.self) { iconName in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(iconName.contains("Dark") ? Color.black : Color.red.opacity(0.85))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "waveform")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(settings.selectedAppIcon == iconName ? Color.cyan : Color.clear, lineWidth: 3)
                                    )
                                
                                Text(iconName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                settings.selectedAppIcon = iconName
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("APP ICON")
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - 6. Lyrics Detail View (Photos 12, 16)
private struct LyricsDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @Binding var storageUsage: String
    @Binding var storedCount: Int
    @Binding var showClearAlert: Bool
    
    let sources = [
        "PaxSenix: Spotify (Spotify lyrics with PaxSenix fallback)",
        "PaxSenix: Musixmatch (Musixmatch timings with PaxSenix fallback)",
        "LyricsPlus (Syllable by syllable, on community)",
        "Unison (Contributed by listeners)",
        "YouTube captions (Timed captions matched to the exact)",
        "YouTube Music (Plain lyrics from playing track)",
        "LRCLIB (Open source LRC database)"
    ]
    
    var body: some View {
        Form {
            Section {
                Toggle("Artist signatures", isOn: $settings.artistSignaturesEnabled)
                    .tint(.cyan)
                Toggle("Synced lyrics", isOn: $settings.syncedLyricsEnabled)
                    .tint(.cyan)
                Toggle("Blur unfocused lyrics", isOn: $settings.blurUnfocusedLyrics)
                    .tint(.cyan)
            } header: {
                Text("DISPLAY")
            }
            
            Section {
                ForEach(sources, id: \.self) { src in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        Text(src)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.cyan)
                            .font(.system(size: 13, weight: .bold))
                    }
                }
            } header: {
                Text("LYRICS SOURCES")
            } footer: {
                Text("Sources are tried in this order. Drag to reorder them. The first source with lyrics wins unless syllable lyrics are prioritized.")
            }
            
            Section {
                Toggle("Auto-Download to Storage", isOn: $settings.autoDownloadLyricsToStorage)
                    .tint(.cyan)
                
                HStack {
                    Text("Storage Consumed")
                    Spacer()
                    Text(storageUsage).foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Saved Tracks")
                    Spacer()
                    Text("\(storedCount) tracks").foregroundColor(.secondary)
                }
                
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Label("Clear Lyrics Storage", systemImage: "trash")
                }
            } header: {
                Text("OFFLINE STORAGE")
            }
        }
        .navigationTitle("Lyrics")
    }
}

// MARK: - 7. Storage Detail View (Photo 28)
private struct StorageDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @Binding var storageUsage: String
    @Binding var showClearAlert: Bool
    @Binding var clearAlertType: String
    
    var body: some View {
        Form {
            Section {
                Toggle("Show cached songs folder", isOn: $settings.showCachedSongsFolder)
                    .tint(.cyan)
            } footer: {
                Text("Adds a Cached songs folder to Library with the songs kept in the song cache.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Song cache limit")
                        Spacer()
                        Text("\(Int(settings.songCacheLimitMB)) MB")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.songCacheLimitMB, in: 256...4096, step: 256)
                        .tint(.cyan)
                }
            } header: {
                Text("CACHE LIMIT")
            } footer: {
                Text("Keeps downloaded audio on disk for instant seeking and replays.")
            }
            
            Section {
                Button {
                    clearAlertType = "Song Cache"
                    showClearAlert = true
                } label: {
                    HStack {
                        Text("Clear song cache")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Frees space")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    clearAlertType = "Image Cache"
                    showClearAlert = true
                } label: {
                    HStack {
                        Text("Clear image cache")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Frees space")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Storage")
    }
}

// MARK: - 8. Local Music Detail View
private struct LocalMusicDetailView: View {
    var body: some View {
        Form {
            Section {
                Button("Scan Device Audio Files") {}
            } header: {
                Text("DEVICE AUDIO")
            } footer: {
                Text("Indexes music files stored locally in your iPhone Files app or synced via iTunes.")
            }
        }
        .navigationTitle("Local Music")
    }
}

// MARK: - 9. Your Data Detail View
private struct YourDataDetailView: View {
    var body: some View {
        Form {
            Section {
                Button("Backup Library & Playlists") {}
                Button("Restore from Backup") {}
            } header: {
                Text("BACKUP & RESTORE")
            }
            
            Section {
                NavigationLink("Spotify Playlist Importer") {
                    Text("Import playlists via Spotify web credentials")
                }
            } header: {
                Text("IMPORT")
            }
        }
        .navigationTitle("Your data")
    }
}

// MARK: - 10. Miscellaneous & Advanced Detail View (Photo 33)
private struct MiscellaneousDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.statsForNerdsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show stats for nerds")
                            .font(.system(size: 15, weight: .medium))
                        Text("Codec, bitrate and sample rate on the player")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)
            } header: {
                Text("DEBUG & TELEMETRY")
            }
            
            Section {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("2.5.0 (Build 42)").foregroundColor(.secondary)
                }
                HStack {
                    Text("Platform")
                    Spacer()
                    Text("iOS (Universal)").foregroundColor(.secondary)
                }
                HStack {
                    Text("Audio Engine")
                    Spacer()
                    Text("CoreAudio + AVPlayer").foregroundColor(.secondary)
                }
            } header: {
                Text("ABOUT")
            }
        }
        .navigationTitle("Miscellaneous")
    }
}

// MARK: - 11. Listen Together Detail View
private struct ListenTogetherDetailView: View {
    @State private var roomCode: String = ""
    
    var body: some View {
        Form {
            Section {
                Button("Host Session") {}
            } header: {
                Text("HOST")
            } footer: {
                Text("Start a synchronized group listening room for friends.")
            }
            
            Section {
                TextField("Enter 6-digit room code", text: $roomCode)
                Button("Join Session") {}
            } header: {
                Text("JOIN")
            }
        }
        .navigationTitle("Listen together")
    }
}
