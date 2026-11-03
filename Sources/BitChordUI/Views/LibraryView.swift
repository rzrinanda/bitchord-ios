import SwiftUI

public struct LibraryView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    
    @State private var offlineLyricsCount: Int = 0
    @State private var offlineLyricsSize: String = ""
    @State private var downloadedCount: Int = 0
    @State private var downloadedSize: String = ""
    @State private var showingSpotifyImporter: Bool = false
    @State private var showingAccountMenu: Bool = false
    @State private var showingHistory: Bool = false
    
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
                            DownloadedSongsView()
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
                                Text("Offline Lyrics Storage")
                                    .font(.system(size: 16, weight: .medium))
                                Text(offlineLyricsCount > 0 ? "\(offlineLyricsCount) Tracks (\(offlineLyricsSize))" : "Active")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Text("Settings")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 80)
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
                                if let art = track.artworkURL {
                                    AsyncImage(url: art) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    BitChordLogoView(size: 44, cornerRadius: 6)
                                }
                                
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
                            if let artURL = track.artworkURL {
                                AsyncImage(url: artURL) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        BitChordLogoView(size: 44, cornerRadius: 6)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                BitChordLogoView(size: 44, cornerRadius: 6)
                            }
                            
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
        .navigationTitle("Downloads")
        .task {
            tracks = await DownloadManager.shared.getDownloadedTracks()
        }
    }
}

public struct SpotifyImporterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var linkText: String = ""
    @State private var isImporting: Bool = false
    @State private var statusMessage: String?
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Paste any public Spotify track or playlist URL to import and match high-res audio on BitChord.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("https://open.spotify.com/track/...", text: $linkText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                if let msg = statusMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Button {
                    importLink()
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Text("Import Music")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(linkText.isEmpty || isImporting)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
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
        statusMessage = "Resolving track metadata..."
        
        Task {
            do {
                let result = try await SpotifyImporter.shared.importFromURL(urlString: trimmed)
                await MainActor.run {
                    if let first = result.tracks.first {
                        AudioPlayerEngine.shared.setQueue(result.tracks)
                        LibraryDatabase.shared.toggleLike(track: first)
                    }
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Could not resolve Spotify URL. Check link and try again."
                    isImporting = false
                }
            }
        }
    }
}
