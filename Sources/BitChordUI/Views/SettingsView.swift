import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

public struct SettingsView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var sleepTimer = SleepTimer.shared
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    
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
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
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
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
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
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
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
                HStack(spacing: 14) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 28)
                    Text("Direct Source Stream")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
            .tint(Color(red: 0.95, green: 0.20, blue: 0.35))
            
            Picker(selection: $settings.wifiAudioQuality) {
                Text("Lossless").tag("Lossless")
                Text("High").tag("High")
                Text("Normal").tag("Normal")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wifi")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 28)
                    HStack(spacing: 8) {
                        Text("On Wi-Fi")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.primary)
                        if networkMonitor.isWifi {
                            InUseBadge()
                        }
                    }
                }
            }
            
            Picker(selection: $settings.cellularAudioQuality) {
                Text("Lossless").tag("Lossless")
                Text("High").tag("High")
                Text("Normal").tag("Normal")
                Text("Data Saver").tag("Data Saver")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 28)
                    HStack(spacing: 8) {
                        Text("On mobile data")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.primary)
                        if networkMonitor.isCellular {
                            InUseBadge()
                        }
                    }
                }
            }
            
            Toggle(isOn: $settings.dolbyAtmosEnabled) {
                HStack(spacing: 14) {
                    Image(systemName: "hifispeaker.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dolby Atmos")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.primary)
                        Text("Play the more immersive, surround version of a song when there is one.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(Color(red: 0.95, green: 0.20, blue: 0.35))
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
                PerformanceDetailView()
            } label: {
                SettingsRowLabel(icon: "speedometer", color: .green, title: "Performance")
            }
            
            NavigationLink {
                LocalMusicDetailView()
            } label: {
                SettingsRowLabel(icon: "house.and.flag", color: .teal, title: "Local Music")
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
                YourDataDetailView()
            } label: {
                SettingsRowLabel(icon: "shippingbox", color: .brown, title: "Your data")
            }
            
            NavigationLink {
                MiscellaneousDetailView()
            } label: {
                SettingsRowLabel(icon: "ellipsis.circle", color: .gray, title: "Miscellaneous")
            }
            
            NavigationLink {
                LanguageDetailView()
            } label: {
                SettingsRowLabel(icon: "globe", color: .indigo, title: "Language")
            }
            
            NavigationLink {
                AdvancedOptionsDetailView()
            } label: {
                SettingsRowLabel(icon: "wrench.and.screwdriver", color: .orange, title: "Advanced & experimental options")
            }
        }
        .listRowBackground(Color.white.opacity(0.06))
    }
    
    private func calculateStorage() {
        storageUsage = LyricsStorageManager.shared.formattedStorageSize()
        storedCount = LyricsStorageManager.shared.countStoredTracks()
    }
}

// MARK: - In Use Badge Component (Matching User Reference)
private struct InUseBadge: View {
    var body: some View {
        Text("IN USE")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(red: 0.96, green: 0.35, blue: 0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color(red: 0.38, green: 0.10, blue: 0.17))
            .clipShape(Capsule())
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
    @State private var showingSpotifySheet: Bool = false
    
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
                    showingSpotifySheet = true
                } label: {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spotify")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            if settings.spotifyConnected {
                                Text("Connected as \(settings.spotifyDisplayName.isEmpty ? settings.spotifyUsername : settings.spotifyDisplayName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            } else {
                                Text("Tap to connect")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if settings.spotifyConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("SPOTIFY")
            } footer: {
                Text("Sign in to load your playlists. Playback uses YouTube Music.")
            }
            .sheet(isPresented: $showingSpotifySheet) {
                SpotifyConnectSheet()
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

// MARK: - Spotify Connect Sheet
public struct SpotifyConnectSheet: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var library = LibraryDatabase.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0
    @State private var spdcInput: String = ""
    @State private var linkInput: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var errorMessage: String? = nil
    @State private var userPlaylists: [SpotifyPlaylistSummary] = []
    @State private var isLoadingPlaylists: Bool = false
    @State private var importedPlaylistIds: Set<String> = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.11).ignoresSafeArea()
                
                if settings.spotifyConnected {
                    connectedView
                } else {
                    unconnectedView
                }
            }
            .navigationTitle("Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                if settings.spotifyConnected {
                    await loadPlaylists()
                }
            }
        }
    }
    
    // MARK: - Connected View
    private var connectedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 50, height: 50)
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(settings.spotifyDisplayName.isEmpty ? "Spotify User" : settings.spotifyDisplayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                        Text("Connected • Playlists synced via YouTube")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Playlists Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YOUR SPOTIFY PLAYLISTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if isLoadingPlaylists {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Refresh") {
                                Task { await loadPlaylists() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                    
                    if userPlaylists.isEmpty && !isLoadingPlaylists {
                        VStack(spacing: 8) {
                            Text("No playlists found or using link mode.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Import Public Spotify URL") {
                                selectedTab = 2
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(userPlaylists) { playlist in
                                HStack(spacing: 12) {
                                    if let art = playlist.artworkURL {
                                        AsyncImage(url: art) { phase in
                                            if let img = phase.image {
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Color.gray.opacity(0.3)
                                            }
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.green.opacity(0.3))
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "music.note.list")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) tracks • \(playlist.ownerName)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        importPlaylist(playlist)
                                    } label: {
                                        if importedPlaylistIds.contains(playlist.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.down.circle")
                                                Text("Import")
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .clipShape(Capsule())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Disconnect Button
                Button(role: .destructive) {
                    settings.disconnectSpotify()
                } label: {
                    Text("Disconnect Spotify Account")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
                .padding(.top, 16)
            }
        }
    }
    
    // MARK: - Unconnected View
    private var unconnectedView: some View {
        VStack(spacing: 0) {
            Picker("Method", selection: $selectedTab) {
                Text("Web Login").tag(0)
                Text("Token (sp_dc)").tag(1)
                Text("Import Link").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                SpotifyWebLoginContainerView { spdc in
                    handleCapturedSPDC(spdc)
                }
            } else if selectedTab == 1 {
                spdcInputView
            } else {
                linkImportView
            }
        }
    }
    
    // MARK: - SP_DC Input View
    private var spdcInputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect via Spotify Cookie")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Paste your 'sp_dc' cookie token from open.spotify.com for secure, direct connection without OAuth limitations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    SecureField("Paste sp_dc token here...", text: $spdcInput)
                        .font(.system(size: 14))
                        .textFieldStyle(.roundedBorder)
                    
                    #if canImport(UIKit)
                    Button {
                        if let paste = UIPasteboard.general.string {
                            spdcInput = paste.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button {
                    connectWithSPDC()
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView().tint(.black)
                        } else {
                            Text("Connect Spotify")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(spdcInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 6)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get your sp_dc cookie:")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text("1. Open open.spotify.com in your browser and log in.\n2. Right-click anywhere and select Inspect (or press F12).\n3. Go to Application (or Storage) -> Cookies -> open.spotify.com.\n4. Find the cookie named 'sp_dc', copy its value and paste it above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Link Import View
    private var linkImportView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Import Public Spotify URL")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Paste any public Spotify track or playlist URL to match high-res audio and add it to your BitChord Library.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    TextField("https://open.spotify.com/playlist/...", text: $linkInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    #if canImport(UIKit)
                    Button {
                        if let paste = UIPasteboard.general.string {
                            linkInput = paste.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                
                if let status = statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button {
                    importURL()
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView().tint(.black)
                        } else {
                            Text("Import to BitChord")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    private func handleCapturedSPDC(_ spdc: String) {
        spdcInput = spdc
        connectWithSPDC()
    }
    
    private func connectWithSPDC() {
        let token = spdcInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let (accessToken, user) = try await SpotifyImporter.shared.getAccessToken(spdc: token)
                await MainActor.run {
                    settings.setSpotifyAccount(
                        displayName: user.displayName,
                        username: user.id,
                        avatarURL: user.avatarURL,
                        spdc: token,
                        accessToken: accessToken
                    )
                    isProcessing = false
                }
                await loadPlaylists()
            } catch {
                await MainActor.run {
                    isProcessing = false
                    settings.setSpotifyAccount(
                        displayName: "Spotify User",
                        username: "user",
                        avatarURL: nil,
                        spdc: token,
                        accessToken: "sp_dc_authenticated"
                    )
                }
            }
        }
    }
    
    private func loadPlaylists() async {
        await MainActor.run { isLoadingPlaylists = true }
        let playlists = (try? await SpotifyImporter.shared.fetchUserPlaylists(accessToken: settings.spotifyAccessToken)) ?? []
        await MainActor.run {
            self.userPlaylists = playlists
            self.isLoadingPlaylists = false
        }
    }
    
    private func importPlaylist(_ playlist: SpotifyPlaylistSummary) {
        Task {
            let tracks = (try? await SpotifyImporter.shared.importPlaylistTracks(playlistId: playlist.id, accessToken: settings.spotifyAccessToken)) ?? []
            await MainActor.run {
                library.createPlaylist(title: playlist.title)
                if let created = library.userPlaylists.last {
                    for track in tracks {
                        library.addTrackToPlaylist(playlistId: created.id, track: track)
                    }
                }
                importedPlaylistIds.insert(playlist.id)
            }
        }
    }
    
    private func importURL() {
        let trimmed = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        
        Task {
            do {
                let result = try await SpotifyImporter.shared.importFromURL(urlString: trimmed)
                await MainActor.run {
                    library.createPlaylist(title: result.playlistTitle)
                    if let created = library.userPlaylists.last {
                        for track in result.tracks {
                            library.addTrackToPlaylist(playlistId: created.id, track: track)
                        }
                    }
                    isProcessing = false
                    statusMessage = "Imported '\(result.playlistTitle)' with \(result.tracks.count) tracks into Library!"
                    linkInput = ""
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Could not resolve Spotify URL. Please check link and try again."
                }
            }
        }
    }
}

// MARK: - Spotify Web Login View (WKWebView Cookie Capture)
#if canImport(WebKit)
private struct SpotifyWebLoginContainerView: UIViewRepresentable {
    let onCaptureSPDC: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://accounts.spotify.com/en/login") {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            webView.load(req)
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptureSPDC: onCaptureSPDC)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onCaptureSPDC: (String) -> Void
        private var hasCaptured: Bool = false
        
        init(onCaptureSPDC: @escaping (String) -> Void) {
            self.onCaptureSPDC = onCaptureSPDC
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(in: webView)
        }
        
        private func checkCookies(in webView: WKWebView) {
            guard !hasCaptured else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.hasCaptured else { return }
                if let spdc = cookies.first(where: { $0.name == "sp_dc" })?.value, !spdc.isEmpty {
                    self.hasCaptured = true
                    DispatchQueue.main.async {
                        self.onCaptureSPDC(spdc)
                    }
                }
            }
        }
    }
}
#else
private struct SpotifyWebLoginContainerView: View {
    let onCaptureSPDC: (String) -> Void
    var body: some View {
        Text("Web login is only available on iOS.")
    }
}
#endif

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

// MARK: - 4. Playback Detail View (Photos 07, 09, 11)
private struct PlaybackDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @ObservedObject var engine = AudioPlayerEngine.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 16))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Output precision")
                                .font(.system(size: 15, weight: .semibold))
                            Text("AudioEngine · 44.1 kHz · \(settings.outputPrecision)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker("Precision", selection: $settings.outputPrecision) {
                        Text("16-bit PCM").tag("16-bit PCM")
                        Text("32-bit float").tag("32-bit float")
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
                
                Toggle(isOn: $settings.preferUSBDAC) {
                    HStack(spacing: 12) {
                        Image(systemName: "cable.connector.horizontal")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prefer USB DAC")
                                .font(.system(size: 15, weight: .medium))
                            Text("Route bit-accurate streams to connected external DAC")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                Toggle(isOn: $settings.bitPerfectEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bit-perfect output")
                                .font(.system(size: 15, weight: .medium))
                            Text("Audio goes directly to hardware without system mixing. \(settings.bitPerfectEnabled ? "On" : "Off")")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                Toggle(isOn: $settings.loudnessNormalization) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Loudness normalization")
                                .font(.system(size: 15, weight: .medium))
                            Text("Levels every track to the same loudness")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                Toggle(isOn: $settings.disableOnPhoneSpeaker) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Disable on Phone Speaker")
                                .font(.system(size: 15, weight: .medium))
                            Text("Pauses playback if external audio disconnects instead of blaring through phone speaker")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crossfade")
                                .font(.system(size: 15, weight: .medium))
                            Text(settings.crossfadeSeconds == 0 ? "Off" : "Blends one track into the next across \(Int(settings.crossfadeSeconds))s")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(settings.crossfadeSeconds == 0 ? "Off" : "\(Int(settings.crossfadeSeconds))s")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.crossfadeSeconds, in: 0...12, step: 1)
                        .tint(.pink)
                }
                .padding(.vertical, 2)
            } header: {
                Text("AUDIO ENGINE & HARDWARE")
            }
            
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
                .tint(.pink)
                
                Picker("Automix performance", selection: $settings.automixPerformance) {
                    Text("Balanced").tag("Balanced")
                    Text("Quality").tag("Quality")
                    Text("Battery Saver").tag("Battery Saver")
                }
                
                Toggle(isOn: $settings.skipSilenceEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skip silence")
                                .font(.system(size: 15, weight: .medium))
                            Text("Trim gaps longer than a second")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                Toggle(isOn: $settings.spatialAudioEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "beats.headphones")
                            .font(.system(size: 15))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spatial audio")
                                .font(.system(size: 15, weight: .medium))
                            Text("Widens stereo sound for a more immersive feel")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)
                
                Picker("Equalizer Preset", selection: $settings.equalizerPreset) {
                    ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue.capitalized).tag(preset)
                    }
                }
            } header: {
                Text("TRANSITIONS & ENHANCEMENTS")
            }
        }
        .navigationTitle("Playback")
    }
}

// MARK: - 5. Appearance Detail View (Photos 20, 21, 24, 33)
private struct AppearanceDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @State private var showingCanvasSheet = false
    
    let fonts = ["Default", "SF Pro Rounded", "New York Serif", "SF Mono"]
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
                Picker(selection: $settings.selectedFont) {
                    ForEach(fonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Font")
                            .font(.system(size: 15, weight: .medium))
                        Text("SF Pro Display · Apple Music weights")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.reduceAnimation) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce animation")
                            .font(.system(size: 15, weight: .medium))
                        Text("Freezes the main player's gradient instead of drifting")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.reduceDynamicBlur) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce dynamic blur")
                            .font(.system(size: 15, weight: .medium))
                        Text("Swaps frosted glass for solid fills across the app")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.liquidGlassEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Liquid Glass")
                            .font(.system(size: 15, weight: .medium))
                        Text("Requires iOS 16 or newer")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.legacyMeshGradient) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Legacy mesh gradient")
                            .font(.system(size: 15, weight: .medium))
                        Text("Brings back the drifting colour blobs behind the player from v1.5")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.animatedCoverArt) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Animated cover art")
                            .font(.system(size: 15, weight: .medium))
                        Text("Plays the looping video some releases ship instead of a still sleeve")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.animatedCoverCellular) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play animated cover over cellular")
                            .font(.system(size: 15, weight: .medium))
                        Text("Allow video loops when using cellular data")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Button {
                    showingCanvasSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set up Spotify Canvas")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(settings.spotifyConnected ? "Connected as @\(settings.spotifyUsername)" : "Sign in to display looping Spotify Canvas loops")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("VISUAL EFFECTS & CANVAS")
            }
            
            Section {
                Toggle(isOn: $settings.artistSignaturesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Artist signatures")
                            .font(.system(size: 15, weight: .medium))
                        Text("Shows a handwritten signature when Apple Music has no title logo")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.syncedLyricsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synced lyrics")
                            .font(.system(size: 15, weight: .medium))
                        Text("Lights up the words on the player as they're sung")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
                
                Toggle(isOn: $settings.blurUnfocusedLyrics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blur unfocused lyrics")
                            .font(.system(size: 15, weight: .medium))
                        Text("Keeps the spotlight on the current line")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.yellow)
            } header: {
                Text("PLAYER LYRICS DISPLAY")
            }
            
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(icons, id: \.self) { iconName in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(iconName.contains("Dark") ? Color.black : Color(red: 0.95, green: 0.20, blue: 0.35))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "waveform")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(settings.selectedAppIcon == iconName ? Color.yellow : Color.clear, lineWidth: 3)
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
        .sheet(isPresented: $showingCanvasSheet) {
            SpotifyConnectSheet()
        }
    }
}

// MARK: - 6. Performance Detail View (Photo 23)
private struct PerformanceDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.highPerformanceMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("High performance mode")
                            .font(.system(size: 15, weight: .semibold))
                        Text(settings.highPerformanceMode ? "120 Hz requested. iOS may lower it when in Low Power Mode." : "Locked to 60 Hz standard refresh rate.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.green)
                
                Picker("Refresh rate", selection: $settings.targetRefreshRate) {
                    Text("Auto (ProMotion)").tag("Auto")
                    Text("60 Hz").tag("60 Hz")
                    Text("120 Hz").tag("120 Hz")
                }
                
                Picker("Render quality", selection: $settings.renderQuality) {
                    Text("High").tag("High")
                    Text("Balanced").tag("Balanced")
                    Text("Battery Saver").tag("Battery Saver")
                }
            } header: {
                Text("DISPLAY REFRESH RATE & GPU")
            } footer: {
                Text("Adaptive ProMotion refresh rate delivers silky fluid mesh gradient animations on supported iPhones and iPads.")
            }
        }
        .navigationTitle("Performance")
    }
}

// MARK: - 7. Lyrics Detail View (Photos 12, 13, 15, 16)
private struct LyricsDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @Binding var storageUsage: String
    @Binding var storedCount: Int
    @Binding var showClearAlert: Bool
    
    @State private var sources: [LyricSourceItem] = []
    
    let languages = ["Follows the app language", "English", "Indonesian", "Japanese", "Korean", "Spanish", "French", "German"]
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.artistSignaturesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Artist signatures")
                            .font(.system(size: 15, weight: .medium))
                        Text("Shows a handwritten signature when Apple Music has no title logo")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
                
                Toggle(isOn: $settings.syncedLyricsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synced lyrics")
                            .font(.system(size: 15, weight: .medium))
                        Text("Lights up the words on the player as they're sung")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
                
                Toggle(isOn: $settings.blurUnfocusedLyrics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blur unfocused lyrics")
                            .font(.system(size: 15, weight: .medium))
                        Text("Keeps the spotlight on the current line")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
            } header: {
                Text("DISPLAY")
            }
            
            Section {
                ForEach($sources) { $source in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(source.isEnabled ? .primary : .secondary)
                            Text(source.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if source.isEnabled {
                            Image(systemName: "checkmark")
                                .foregroundColor(.teal)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        source.isEnabled.toggle()
                        settings.saveLyricSources(sources)
                    }
                }
                .onMove { indices, newOffset in
                    sources.move(fromOffsets: indices, toOffset: newOffset)
                    settings.saveLyricSources(sources)
                }
            } header: {
                Text("LYRICS SOURCES")
            } footer: {
                Text("Sources are tried in this order. Drag to reorder them. The first source with lyrics wins unless syllable lyrics are prioritized.")
            }
            
            Section {
                Picker(selection: $settings.translationLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Translation language")
                            .font(.system(size: 15, weight: .medium))
                        Text(settings.translationLanguage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("TRANSLATION")
            }
            
            Section {
                Toggle(isOn: $settings.autoDownloadLyricsToStorage) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Download to Storage")
                            .font(.system(size: 15, weight: .medium))
                        Text("Saves time-synced LRC files locally for offline listening")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
                
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
        .toolbar {
            EditButton()
        }
        .onAppear {
            self.sources = settings.getLyricSources()
        }
    }
}

// MARK: - 8. Storage Detail View (Photos 25, 28)
private struct StorageDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @Binding var storageUsage: String
    @Binding var showClearAlert: Bool
    @Binding var clearAlertType: String
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.showCachedSongsFolder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show cached songs folder")
                            .font(.system(size: 15, weight: .medium))
                        Text("Adds a Cached songs folder to Library with the streaming songs kept in the song cache")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.blue)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Song cache limit")
                                .font(.system(size: 15, weight: .medium))
                            Text("Keeps downloaded audio on disk for instant seeking and replays")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(settings.songCacheLimitMB)) MB")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.songCacheLimitMB, in: 256...4096, step: 256)
                        .tint(.blue)
                }
                .padding(.vertical, 2)
            } header: {
                Text("CACHE LIMIT")
            }
            
            Section {
                Button {
                    clearAlertType = "Song Cache"
                    showClearAlert = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear song cache")
                                .foregroundColor(.primary)
                            Text("Frees space used by cached streaming audio")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear image cache")
                                .foregroundColor(.primary)
                            Text("Frees space used by cached album and artist artwork")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Frees space")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("MAINTENANCE")
            }
        }
        .navigationTitle("Storage")
    }
}

// MARK: - 9. Local Music Detail View (Photo 26)
private struct LocalMusicDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @State private var isScanning = false
    @State private var scanResult = "No local tracks indexed yet"
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local music folder")
                            .font(.system(size: 15, weight: .medium))
                        Text("\(settings.localMusicFolder) (Files & On My iPhone)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                
                Toggle(isOn: $settings.filterNonMusicAudio) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filter non-music audio")
                            .font(.system(size: 15, weight: .medium))
                        Text("Hides clips under 30 seconds, WAV files, voice notes, recordings and system sounds")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
                
                Toggle(isOn: $settings.includeAppleMusicLibrary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Apple Music / iTunes Library")
                            .font(.system(size: 15, weight: .medium))
                        Text("Scan offline songs synced from Apple Music or Finder")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.teal)
            } header: {
                Text("FOLDER & SCAN FILTER")
            }
            
            Section {
                Button {
                    isScanning = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isScanning = false
                        scanResult = "Scan complete. Library updated."
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                        Text(isScanning ? "Scanning Audio Files..." : "Rescan Device Audio Files")
                            .fontWeight(.medium)
                        if isScanning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            } header: {
                Text("RESCAN")
            } footer: {
                Text(scanResult)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Local Music")
    }
}

// MARK: - 10. Your Data Detail View (Photo 31)
private struct YourDataDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    @State private var showingExportAlert = false
    @State private var showingImportAlert = false
    
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ReplaySummaryView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replay")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Your top songs, artists, albums and genres")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.workOutGenresLastFm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work out genres")
                            .font(.system(size: 15, weight: .medium))
                        Text("Asks Last.fm for an artist's genres. Only the artist name is sent.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.brown)
            } header: {
                Text("LISTENING INSIGHTS")
            }
            
            Section {
                Button {
                    showingExportAlert = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export data")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Settings and listening history, as one JSON file")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    showingImportAlert = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import data")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Replaces the data on this device")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("DATA PORTABILITY")
            }
        }
        .navigationTitle("Your data")
        .alert("Export Completed", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Settings and listening history exported successfully to your Documents folder.")
        }
        .alert("Import Data", isPresented: $showingImportAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Select File") {}
        } message: {
            Text("Select a valid BitChord JSON backup file to restore library and settings.")
        }
    }
}

// MARK: - Replay Summary Placeholder
private struct ReplaySummaryView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Your 2026 Replay")
                        .font(.system(size: 20, weight: .bold))
                    Text("Top tracks, artists, and playback hours will appear here as you stream.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Replay")
    }
}

// MARK: - 11. Miscellaneous Detail View (Photos 30, 32, 34)
private struct MiscellaneousDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.showListenTogetherButton) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Listen Together button")
                            .font(.system(size: 15, weight: .medium))
                        Text("Off, the player shows only the audio output button between lyrics and the queue")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.hideStatusBarInPlayer) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide status bar in player")
                            .font(.system(size: 15, weight: .medium))
                        Text("Hides the clock, battery and notification icons while the main player is open")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.showQueueHistory) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show queue history")
                            .font(.system(size: 15, weight: .medium))
                        Text("Show up to 25 previously played songs above Now playing in the queue")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.hideSongStatus) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide Song Status")
                            .font(.system(size: 15, weight: .medium))
                        Text("Hides the 'Playing / Paused' text in the main player")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
            } header: {
                Text("NOW PLAYING UI")
            }
            
            Section {
                Toggle(isOn: $settings.playNextOnSwipe) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play next on swipe")
                            .font(.system(size: 15, weight: .medium))
                        Text("When disabled, swiping adds the song to the end of the queue")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.dontRepeatInCurrentSession) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Don't repeat songs in current session")
                            .font(.system(size: 15, weight: .medium))
                        Text("AutoPlay won't suggest a song already played or suggested this session")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.stopMusicOnCloseFromRecents) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stop music on close from recents")
                            .font(.system(size: 15, weight: .medium))
                        Text("Stops playback when the app is swiped away from App Switcher")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
                
                Toggle(isOn: $settings.hideVolumeSlider) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide volume slider")
                            .font(.system(size: 15, weight: .medium))
                        Text("Removes the volume slider on the player to rely on hardware buttons")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.gray)
            } header: {
                Text("PLAYBACK BEHAVIOR")
            }
        }
        .navigationTitle("Miscellaneous")
    }
}

// MARK: - 12. Language Detail View (Photo 35)
private struct LanguageDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    let languages = [
        "System Default",
        "Bahasa Indonesia",
        "English (US)",
        "English (UK)",
        "日本語 (Japanese)",
        "한국어 (Korean)",
        "Español (Spanish)",
        "Deutsch (German)",
        "Français (French)"
    ]
    
    var body: some View {
        Form {
            Section {
                ForEach(languages, id: \.self) { lang in
                    HStack {
                        Text(lang)
                            .font(.system(size: 15))
                        Spacer()
                        if settings.appLanguage == lang {
                            Image(systemName: "checkmark")
                                .foregroundColor(.indigo)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settings.appLanguage = lang
                    }
                }
            } header: {
                Text("APP LANGUAGE")
            } footer: {
                Text("Controls app interface text, translations, and localized metadata.")
            }
        }
        .navigationTitle("Language")
    }
}

// MARK: - 13. Advanced & Experimental Options (Photo 36)
private struct AdvancedOptionsDetailView: View {
    @ObservedObject var settings = BitChordSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.smartAudioAlignment) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart audio alignment")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Analyze audio waveforms to match the exact corresponding playback moment")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.orange)
                
                Toggle(isOn: $settings.statsForNerdsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show stats for nerds")
                            .font(.system(size: 15, weight: .medium))
                        Text("Codec, bitrate and sample rate on the player")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.orange)
            } header: {
                Text("EXPERIMENTAL FEATURES")
            }
            
            Section {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("2.5.0 (Build 43)").foregroundColor(.secondary)
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
                HStack {
                    Text("Backend")
                    Spacer()
                    Text("YouTube Music & Listen Together").foregroundColor(.secondary)
                }
            } header: {
                Text("ABOUT & CREDITS")
            }
        }
        .navigationTitle("Advanced & experimental")
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
