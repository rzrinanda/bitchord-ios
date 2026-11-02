import SwiftUI

public struct LibraryView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    
    @State private var offlineLyricsCount: Int = 0
    @State private var offlineLyricsSize: String = ""
    @State private var downloadedCount: Int = 0
    @State private var downloadedSize: String = ""
    @State private var showingSpotifyImporter: Bool = false
    @State private var showingNewPlaylistAlert: Bool = false
    @State private var newPlaylistTitle: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TrackListView(title: "Liked Songs", tracks: library.likedTracks)
                    } label: {
                        HStack {
                            Label("Liked Songs", systemImage: "heart.fill")
                                .foregroundColor(.red)
                            Spacer()
                            Text("\(library.likedTracks.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        PlaylistsDetailView()
                    } label: {
                        HStack {
                            Label("Playlists", systemImage: "music.note.list")
                            Spacer()
                            Text("\(library.userPlaylists.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        DownloadedSongsView()
                    } label: {
                        HStack {
                            Label("Downloaded Music", systemImage: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Text(downloadedSize)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Spotify Playlist Importer (BitChord Feature)
                Section("Integrations") {
                    Button {
                        showingSpotifyImporter = true
                    } label: {
                        Label("Import from Spotify", systemImage: "square.and.arrow.down")
                            .foregroundColor(.primary)
                    }
                }
                
                // Offline Lyrics Storage (Switchable feature)
                Section("Offline Lyrics Storage") {
                    HStack {
                        Label("Cached Lyrics", systemImage: "quote.bubble.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(offlineLyricsCount) Tracks (\(offlineLyricsSize))")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("Configure Storage & Auto-Download")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Library")
            .sheet(isPresented: $showingSpotifyImporter) {
                SpotifyImporterSheet()
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
                        var shuffled = tracks
                        shuffled.shuffle()
                        engine.setQueue(shuffled, startIndex: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                Button {
                    engine.setQueue(tracks, startIndex: index)
                } label: {
                    HStack(spacing: 12) {
                        if let art = track.artworkURL {
                            AsyncImage(url: art) { ph in
                                if let img = ph.image { img.resizable().aspectRatio(contentMode: .fill) }
                                else { Color.gray.opacity(0.2) }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(track.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

public struct DownloadedSongsView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var tracks: [Track] = []
    
    public var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView("No Offline Songs", systemImage: "arrow.down.circle", description: Text("Tracks you download will appear here for offline playback without internet."))
            } else {
                ForEach(tracks) { track in
                    Button {
                        engine.setQueue([track])
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.title).font(.body)
                                Text(track.artist).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = tracks[index].id
                        Task {
                            await DownloadManager.shared.removeDownload(trackId: id)
                            tracks.remove(at: index)
                        }
                    }
                }
            }
        }
        .navigationTitle("Downloaded Music")
        .task {
            tracks = await DownloadManager.shared.getDownloadedTracks()
        }
    }
}

public struct PlaylistsDetailView: View {
    @ObservedObject var library = LibraryDatabase.shared
    @State private var showingAddAlert: Bool = false
    @State private var newTitle: String = ""
    
    public var body: some View {
        List {
            ForEach(library.userPlaylists) { playlist in
                NavigationLink {
                    TrackListView(title: playlist.title, tracks: playlist.tracks)
                } label: {
                    VStack(alignment: .leading) {
                        Text(playlist.title).font(.headline)
                        Text("\(playlist.tracks.count) tracks").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $showingAddAlert) {
            TextField("Playlist Title", text: $newTitle)
            Button("Cancel", role: .cancel) { newTitle = "" }
            Button("Create") {
                if !newTitle.isEmpty {
                    library.createPlaylist(title: newTitle)
                    newTitle = ""
                }
            }
        }
    }
}

public struct SpotifyImporterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    
    @State private var spotifyURL: String = ""
    @State private var isImporting: Bool = false
    @State private var importResult: SpotifyImportResult?
    @State private var errorMessage: String?
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Enter Spotify Link") {
                    TextField("https://open.spotify.com/playlist/...", text: $spotifyURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button {
                        startImport()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Import and Match Songs")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(spotifyURL.isEmpty || isImporting)
                }
                
                if let result = importResult {
                    Section("Imported: \(result.playlistTitle)") {
                        Text("\(result.tracks.count) songs matched in BitChord")
                            .foregroundColor(.secondary)
                        Button("Play Now") {
                            engine.setQueue(result.tracks)
                            dismiss()
                        }
                        Button("Save as Playlist") {
                            library.createPlaylist(title: result.playlistTitle)
                            if let last = library.userPlaylists.last {
                                for t in result.tracks {
                                    library.addTrackToPlaylist(playlistId: last.id, track: t)
                                }
                            }
                            dismiss()
                        }
                    }
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Spotify Importer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func startImport() {
        isImporting = true
        errorMessage = nil
        Task {
            do {
                let res = try await SpotifyImporter.shared.importFromURL(urlString: spotifyURL)
                self.importResult = res
            } catch {
                self.errorMessage = "Could not import: Please ensure the Spotify link is public."
            }
            self.isImporting = false
        }
    }
}
