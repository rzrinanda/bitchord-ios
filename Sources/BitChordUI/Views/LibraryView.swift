import SwiftUI

public struct LibraryView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var settings = BitChordSettings.shared
    
    @State private var offlineLyricsCount: Int = 0
    @State private var offlineLyricsSize: String = ""
    @State private var downloadedCount: Int = 0
    @State private var downloadedSize: String = ""
    @State private var showingSpotifyImporter: Bool = false
    @State private var showingAccountMenu: Bool = false
    @State private var showingHistory: Bool = false
    @ObservedObject private var localScanner = LocalMusicScanner.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Section: Your Listening Experience (Matching Car HU Photo 3)
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                // Card 1: Minutes Listened
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("YOUR LISTENING EXPERIENCE")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        BitChordLogoView(size: 18, cornerRadius: 4)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(library.totalMinutesListened)")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.primary)
                                    + Text(" MINUTES LISTENED")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(accountManager.activeAccount.displayName.uppercased())
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("16 plays • 2026")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("MEMBER SINCE")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Text(accountManager.activeAccount.memberSince)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                                .padding(16)
                                .frame(width: 260, height: 160)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                
                                // Card 2: Top Song (Kangen / Dewa 19)
                                Button {
                                    let kangen = Track(
                                        id: "utgn0LCDirk",
                                        title: "Kangen",
                                        artist: "Dewa 19",
                                        album: "19",
                                        duration: 312,
                                        artworkURL: URL(string: "https://i.ytimg.com/vi/utgn0LCDirk/hqdefault.jpg"),
                                        isLossless: true
                                    )
                                    engine.setQueue([kangen], startIndex: 0)
                                    library.recordPlayback(track: kangen)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("YOUR LISTENING EXPERIENCE")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            BitChordLogoView(size: 18, cornerRadius: 4)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("Kangen")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text("TOP SONG")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(accountManager.activeAccount.displayName.uppercased())
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.primary)
                                                Text("Dewa 19 • 1 plays")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("MEMBER SINCE")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(.secondary)
                                                Text(accountManager.activeAccount.memberSince)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .frame(width: 260, height: 160)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 4)
                    
                    // MARK: - Navigation Menu Rows (Matching Car HU Photo 3)
                    VStack(spacing: 0) {
                        NavigationLink {
                            DownloadedSongsView()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text("Downloads")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(downloadedSize.isEmpty ? "\(downloadedCount)" : downloadedSize)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        NavigationLink {
                            LocalMusicListView()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text("Local Music")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(localScanner.tracks.count)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        NavigationLink {
                            TrackListView(title: "Liked Songs", tracks: library.likedTracks)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 28)
                                Text("Liked Songs")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(library.likedTracks.count)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        NavigationLink {
                            PlaylistsDetailView()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text("Playlists")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(library.userPlaylists.count)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        Button {
                            showingSpotifyImporter = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text("Import from Spotify")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.leading, 60)
                        
                        // Switchable Offline Lyrics Storage
                        HStack(spacing: 16) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.cyan)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Download Lyrics")
                                    .font(.system(size: 16, weight: .medium))
                                Text(offlineLyricsCount > 0 ? "\(offlineLyricsCount) Tracks (\(offlineLyricsSize))" : (settings.autoDownloadLyricsToStorage ? "Active • Offline storage enabled" : "Disabled"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.autoDownloadLyricsToStorage)
                                .labelsHidden()
                                .tint(.cyan)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 165)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            showingHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            showingAccountMenu = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.85))
                                    .frame(width: 32, height: 32)
                                Text(accountManager.activeAccount.avatarLetter)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSpotifyImporter) {
                SpotifyImporterSheet()
            }
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    TrackListView(title: "Listening History", tracks: library.recentTracks)
                }
            }
            .task {
                offlineLyricsCount = await LyricsManager.shared.getDownloadedLyricsCount()
                offlineLyricsSize = await LyricsManager.shared.getStorageUsageString()
                let downloaded = await DownloadManager.shared.getDownloadedTracks()
                downloadedCount = downloaded.count
                downloadedSize = await DownloadManager.shared.getTotalDownloadedSizeString()
                if localScanner.tracks.isEmpty {
                    _ = await localScanner.scan()
                }
            }
        }
    }
}

public struct TrackListView: View {
    public let title: String
    public let tracks: [Track]
    @ObservedObject var engine = AudioPlayerEngine.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrackForMenu: Track? = nil
    
    public var body: some View {
        List {
            if !tracks.isEmpty {
                HStack(spacing: 16) {
                    Button {
                        engine.setQueue(tracks, startIndex: 0)
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button {
                        engine.setQueue(tracks.shuffled(), startIndex: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
                .listRowSeparator(.hidden)
            }
            
            if tracks.isEmpty {
                ContentUnavailableView("No Tracks", systemImage: "music.note", description: Text("No tracks found."))
            } else {
                ForEach(tracks) { track in
                    HStack(spacing: 12) {
                        Button {
                            let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                            engine.setQueue(tracks, startIndex: idx)
                        } label: {
                            HStack(spacing: 12) {
                                TrackArtworkView(track: track, size: 44, cornerRadius: 6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if engine.currentTrack?.id == track.id {
                                    Image(systemName: "waveform")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                                selectedTrackForMenu = track
                            }
                        )
                        
                        Button {
                            selectedTrackForMenu = track
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedTrackForMenu) { track in
            TrackContextMenuSheet(track: track)
        }
    }
}

public struct PlaylistsDetailView: View {
    @ObservedObject var library = LibraryDatabase.shared
    @State private var showingCreate: Bool = false
    @State private var title: String = ""
    
    public var body: some View {
        List {
            ForEach(library.userPlaylists) { playlist in
                NavigationLink {
                    TrackListView(title: playlist.title, tracks: playlist.tracks)
                } label: {
                    HStack(spacing: 12) {
                        if let firstTrack = playlist.tracks.first {
                            TrackArtworkView(track: firstTrack, size: 46, cornerRadius: 8)
                        } else {
                            BitChordLogoView(size: 46, cornerRadius: 8)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.title)
                                .font(.headline)
                            Text("\(playlist.tracks.count) tracks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $showingCreate) {
            TextField("Playlist Title", text: $title)
            Button("Cancel", role: .cancel) { title = "" }
            Button("Create") {
                if !title.isEmpty {
                    library.createPlaylist(title: title)
                    title = ""
                }
            }
        }
    }
}

// MARK: - Local Music List View
public struct LocalMusicListView: View {
    @ObservedObject private var scanner = LocalMusicScanner.shared
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var searchText: String = ""
    
    public init() {}
    
    private var filteredTracks: [Track] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return scanner.tracks
        }
        return scanner.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText) ||
            $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        TrackListView(title: "Local Music", tracks: filteredTracks)
            .searchable(text: $searchText, prompt: "Search local tracks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if scanner.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task {
                                _ = await scanner.scan()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .task {
                if scanner.tracks.isEmpty {
                    _ = await scanner.scan()
                }
            }
    }
}

public struct DownloadedSongsView: View {
    @State private var tracks: [Track] = []
    @ObservedObject var engine = AudioPlayerEngine.shared
    
    public var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Tracks downloaded for offline listening will appear here."))
            } else {
                ForEach(tracks) { track in
                    Button {
                        let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                        engine.setQueue(tracks, startIndex: idx)
                    } label: {
                        HStack(spacing: 12) {
                            TrackArtworkView(track: track, size: 44, cornerRadius: 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
        }
        .navigationTitle("Downloads")
        .task {
            tracks = await DownloadManager.shared.getDownloadedTracks()
        }
    }
}

public struct SpotifyImporterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var linkText: String = ""
    @State private var isImporting: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isSuccess: Bool = false
    @State private var importedTracks: [Track] = []
    @State private var importedTitle: String = ""
    
    private let quickSamples: [(name: String, url: String)] = [
        ("Top Hits Indonesia", "https://open.spotify.com/playlist/37i9dQZF1DXdPec7aLTmlC"),
        ("NOAH Best Tracks", "NOAH Official Top Songs"),
        ("Dewa 19 Classics", "Dewa 19 Terbaik"),
        ("Global Top 50", "https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF")
    ]
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Banner
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import from Spotify")
                                .font(.system(size: 18, weight: .bold))
                            Text("Paste any Spotify Track, Album, or Playlist URL (or search name) to import & match Lossless audio.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // URL / Query Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPOTIFY URL OR PLAYLIST NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("https://open.spotify.com/playlist/... or Track", text: $linkText)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !linkText.isEmpty {
                                Button {
                                    linkText = ""
                                    statusMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            #if canImport(UIKit)
                            Button {
                                if let pasted = UIPasteboard.general.string {
                                    linkText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    
                    // Quick Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUICK IMPORT PRESETS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickSamples, id: \.name) { sample in
                                    Button {
                                        linkText = sample.url
                                        importLink()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 11))
                                            Text(sample.name)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.secondary.opacity(0.14))
                                        .foregroundColor(.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if let msg = statusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : (isImporting ? "hourglass" : "exclamationmark.triangle.fill"))
                                .foregroundColor(isSuccess ? .green : (isImporting ? .cyan : .orange))
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isSuccess ? .green : .secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        importLink()
                    } label: {
                        HStack(spacing: 10) {
                            Spacer()
                            if isImporting {
                                ProgressView()
                                    .tint(.black)
                                Text("Matching High-Res Catalog...")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .foregroundColor(.black)
                                Text("Import to Library & Play")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 13)
                        .background(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting ? Color.green.opacity(0.4) : Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                    
                    // Imported Results Preview
                    if !importedTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("IMPORTED: \(importedTitle.uppercased()) (\(importedTracks.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Play All") {
                                    engine.setQueue(importedTracks, startIndex: 0)
                                    if let first = importedTracks.first {
                                        library.recordPlayback(track: first)
                                    }
                                    dismiss()
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                            }
                            
                            ForEach(importedTracks) { track in
                                HStack(spacing: 12) {
                                    TrackArtworkView(track: track, size: 42, cornerRadius: 8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Import from Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func importLink() {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isImporting = true
        isSuccess = false
        statusMessage = "Resolving Spotify metadata & matching full-length tracks..."
        
        Task {
            do {
                let result = try await SpotifyImporter.shared.importFromURL(urlString: trimmed)
                await MainActor.run {
                    self.importedTitle = result.playlistTitle
                    self.importedTracks = result.tracks
                    
                    // Save as a playlist in LibraryDatabase and also like if single track
                    if result.tracks.count == 1, let single = result.tracks.first {
                        if !library.isLiked(trackId: single.id) {
                            library.toggleLike(track: single)
                        }
                        library.recordPlayback(track: single)
                    } else if !result.tracks.isEmpty {
                        library.createPlaylist(title: result.playlistTitle, description: "Imported from Spotify")
                        if let created = library.userPlaylists.last {
                            for track in result.tracks {
                                library.addTrackToPlaylist(playlistId: created.id, track: track)
                            }
                        }
                    }
                    
                    if let first = result.tracks.first {
                        engine.setQueue(result.tracks, startIndex: 0)
                        library.recordPlayback(track: first)
                    }
                    
                    isImporting = false
                    isSuccess = true
                    statusMessage = "Successfully imported '\(result.playlistTitle)' (\(result.tracks.count) track\(result.tracks.count == 1 ? "" : "s")) to Library!"
                }
            } catch {
                await MainActor.run {
                    isSuccess = false
                    statusMessage = "Could not resolve Spotify URL. Please check the link or try pasting a song/playlist title."
                    isImporting = false
                }
            }
        }
    }
}
