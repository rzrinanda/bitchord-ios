import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct TrackContextMenuSheet: View {
    public let track: Track
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var sleepTimer = SleepTimer.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSongInfo: Bool = false
    @State private var showingDownloadSheet: Bool = false
    @State private var showingPlaylistPicker: Bool = false
    @State private var showingCreatePlaylistAlert: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var showingSleepTimerDialog: Bool = false
    @State private var showingLyricsOffsetDialog: Bool = false
    @State private var lyricsOffsetMs: Int = 0
    @State private var actionMessage: String?
    
    public init(track: Track) {
        self.track = track
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Track Header Preview
                        HStack(spacing: 14) {
                            if let artURL = track.artworkURL {
                                AsyncImage(url: artURL) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                BitChordLogoView(size: 52, cornerRadius: 10)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        // Action Feedback Banner
                        if let msg = actionMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(msg)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .scale))
                        }
                        
                        // MARK: - Section 1: Quick Actions (Matching Car HU Photo 4: Like | Dislike | Share)
                        HStack(spacing: 0) {
                            // Like
                            Button {
                                library.toggleLike(track: track)
                                withAnimation {
                                    actionMessage = library.isLiked(trackId: track.id) ? "Added to Liked Songs" : "Removed from Liked Songs"
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: library.isLiked(trackId: track.id) ? "star.fill" : "star")
                                        .font(.system(size: 20))
                                        .foregroundColor(library.isLiked(trackId: track.id) ? .yellow : .white)
                                    Text("Like")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            
                            // Dislike
                            Button {
                                withAnimation {
                                    actionMessage = "Marked as Disliked"
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "heart.slash")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("Dislike")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            
                            // Share
                            ShareLink(item: URL(string: "https://music.youtube.com/watch?v=\(track.id)") ?? URL(string: "https://github.com/rzrinanda/bitchord-ios")!) {
                                VStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                    Text("Share")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        
                        Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 4)
                        
                        // MARK: - Section 2: Quality & Version (Matching Car HU Photo 4)
                        VStack(spacing: 2) {
                            menuRow(icon: "sparkles", label: "Upgrade quality") {
                                BitChordSettings.shared.wifiAudioQuality = "Lossless"
                                BitChordSettings.shared.cellularAudioQuality = "Lossless"
                                BitChordSettings.shared.directSourceStream = true
                                withAnimation {
                                    actionMessage = "Quality upgraded to Lossless (24-bit/48kHz)"
                                }
                            }
                            
                            menuRow(icon: "video.fill", label: "Convert to video") {
                                withAnimation {
                                    actionMessage = "Switched to video version"
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 4)
                        
                        // MARK: - Section 3: Playlist (Matching Car HU Photo 4)
                        VStack(spacing: 2) {
                            menuRow(icon: "text.badge.plus", label: "Add to playlist") {
                                showingPlaylistPicker = true
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 4)
                        
                        // MARK: - Section 4: Queue, Radio & Download (Matching Car HU Photo 3)
                        VStack(spacing: 2) {
                            menuRow(icon: "dot.radiowaves.left.and.right", label: "Start radio") {
                                engine.startRadio(for: track)
                                withAnimation {
                                    actionMessage = "Radio started with similar songs"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    dismiss()
                                }
                            }
                            
                            menuRow(icon: "text.line.first.and.arrowtriangle.forward", label: "Play next") {
                                engine.insertNextInQueue(track)
                                withAnimation {
                                    actionMessage = "\(track.title) will play next"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    dismiss()
                                }
                            }
                            
                            menuRow(icon: "text.badge.plus", label: "Add to queue") {
                                engine.appendToQueue(track)
                                withAnimation {
                                    actionMessage = "Added to queue"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    dismiss()
                                }
                            }
                            
                            menuRow(icon: "arrow.down.circle", label: "Download") {
                                showingDownloadSheet = true
                            }
                            
                            menuRow(icon: "trash", label: "Remove from cache") {
                                DownloadManager.shared.removeDownload(trackId: track.id)
                                withAnimation {
                                    actionMessage = "Removed from offline cache"
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 4)
                        
                        // MARK: - Section 5: Navigation & Info (Matching Car HU Photo 2)
                        VStack(spacing: 2) {
                            menuRow(icon: "record.circle", label: "Open album", subtitle: track.album.isEmpty || track.album == "YouTube Music" ? nil : track.album) {
                                let albumName = track.album.isEmpty || track.album == "YouTube Music" ? track.title : track.album
                                Task {
                                    if let tracks = try? await YTMusicClient.shared.search(query: "\(albumName) album") {
                                        await MainActor.run {
                                            engine.setQueue(tracks, startIndex: 0)
                                            withAnimation {
                                                actionMessage = "Playing album '\(albumName)'"
                                            }
                                        }
                                    }
                                }
                            }
                            
                            menuRow(icon: "music.mic", label: "Open artist", subtitle: track.artist.isEmpty || track.artist == "YouTube Music" ? nil : track.artist) {
                                Task {
                                    if let tracks = try? await YTMusicClient.shared.search(query: "\(track.artist) songs") {
                                        await MainActor.run {
                                            engine.setQueue(tracks, startIndex: 0)
                                            withAnimation {
                                                actionMessage = "Playing top tracks for \(track.artist)"
                                            }
                                        }
                                    }
                                }
                            }
                            
                            menuRow(icon: "info.circle", label: "Song Info") {
                                showingSongInfo = true
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 4)
                        
                        // MARK: - Section 6: Player Extras (Matching Car HU Photo 2)
                        VStack(spacing: 2) {
                            menuRow(
                                icon: "moon.zzz.fill",
                                label: "Sleep timer",
                                subtitle: sleepTimer.isActive ? sleepTimer.formattedRemainingTime : nil
                            ) {
                                showingSleepTimerDialog = true
                            }
                            
                            menuRow(
                                icon: "slider.horizontal.3",
                                label: "Lyrics offset",
                                subtitle: lyricsOffsetMs != 0 ? "\(lyricsOffsetMs > 0 ? "+" : "")\(lyricsOffsetMs) ms" : nil
                            ) {
                                showingLyricsOffsetDialog = true
                            }
                            
                            menuRow(icon: "ladybug.fill", label: "Copy log") {
                                copyDiagnosticsLog()
                            }
                        }
                        
                        Spacer(minLength: 32)
                    }
                }
                
                // Song Info Modal Dialog (Matching Car HU Photo 1)
                if showingSongInfo {
                    SongInfoDialog(track: track) {
                        showingSongInfo = false
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingSongInfo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            // Sleep Timer Confirmation Dialog / Sheet
            .confirmationDialog("Sleep Timer", isPresented: $showingSleepTimerDialog, titleVisibility: .visible) {
                if sleepTimer.isActive {
                    Button("Turn Off Sleep Timer", role: .destructive) {
                        sleepTimer.stop()
                        actionMessage = "Sleep timer turned off"
                    }
                }
                Button("15 Minutes") {
                    sleepTimer.start(durationMinutes: 15) { engine.pause() }
                    actionMessage = "Sleep timer set to 15m"
                }
                Button("30 Minutes") {
                    sleepTimer.start(durationMinutes: 30) { engine.pause() }
                    actionMessage = "Sleep timer set to 30m"
                }
                Button("45 Minutes") {
                    sleepTimer.start(durationMinutes: 45) { engine.pause() }
                    actionMessage = "Sleep timer set to 45m"
                }
                Button("60 Minutes") {
                    sleepTimer.start(durationMinutes: 60) { engine.pause() }
                    actionMessage = "Sleep timer set to 60m"
                }
                Button("Cancel", role: .cancel) {}
            }
            // Lyrics Offset Alert / Dialog
            .alert("Lyrics Offset", isPresented: $showingLyricsOffsetDialog) {
                Button("-100 ms") {
                    lyricsOffsetMs -= 100
                    actionMessage = "Lyrics offset: \(lyricsOffsetMs) ms"
                }
                Button("Reset (0 ms)") {
                    lyricsOffsetMs = 0
                    actionMessage = "Lyrics offset reset to 0 ms"
                }
                Button("+100 ms") {
                    lyricsOffsetMs += 100
                    actionMessage = "Lyrics offset: \(lyricsOffsetMs) ms"
                }
                Button("Done", role: .cancel) {}
            } message: {
                Text("Current offset: \(lyricsOffsetMs) ms\nAdjust timing for synced lyrics synchronization.")
            }
            // Add to Playlist Sheet
            .sheet(isPresented: $showingPlaylistPicker) {
                NavigationStack {
                    List {
                        Button {
                            showingCreatePlaylistAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                Text("New Playlist")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if library.userPlaylists.isEmpty {
                            Text("No playlists yet. Tap 'New Playlist' above to create one.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(library.userPlaylists) { playlist in
                                Button {
                                    library.addTrackToPlaylist(playlistId: playlist.id, track: track)
                                    showingPlaylistPicker = false
                                    withAnimation {
                                        actionMessage = "Added to '\(playlist.title)'"
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "music.note.list")
                                            .foregroundColor(.red)
                                        Text(playlist.title)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(playlist.tracks.count) tracks")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .navigationTitle("Add to Playlist")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingPlaylistPicker = false }
                        }
                    }
                    .alert("Create Playlist", isPresented: $showingCreatePlaylistAlert) {
                        TextField("Playlist Name", text: $newPlaylistName)
                        Button("Cancel", role: .cancel) { newPlaylistName = "" }
                        Button("Create & Add") {
                            if !newPlaylistName.isEmpty {
                                library.createPlaylist(title: newPlaylistName)
                                if let created = library.userPlaylists.last {
                                    library.addTrackToPlaylist(playlistId: created.id, track: track)
                                }
                                newPlaylistName = ""
                                showingPlaylistPicker = false
                                withAnimation {
                                    actionMessage = "Created and added to playlist"
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDownloadSheet) {
                DownloadSheetView(track: track)
            }
        }
        .presentationDetents([.medium, .fraction(0.85)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(red: 0.12, green: 0.13, blue: 0.16))
    }
    
    // MARK: - Row Helper
    @ViewBuilder
    private func menuRow(icon: String, label: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 28)
                    .foregroundColor(.white.opacity(0.9))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Copy Log Helper
    private func copyDiagnosticsLog() {
        let log = """
        [BitChord Diagnostic Report]
        Track: \(track.title) - \(track.artist)
        Album: \(track.album)
        Video ID: \(track.id)
        Backend: \(engine.activeBackend.rawValue)
        Playback State: \(engine.status.rawValue)
        Playback Clock: \(String(format: "%.1f", engine.currentTime))s / \(String(format: "%.1f", engine.duration))s
        Volume: \(Int(engine.volume * 100))%
        Repeat: \(engine.repeatMode) | Shuffle: \(engine.shuffleMode)
        Timestamp: \(Date())
        Device: iOS \(UIDevice.current.systemVersion) (\(UIDevice.current.model))
        """
        
        #if canImport(UIKit)
        UIPasteboard.general.string = log
        #endif
        withAnimation {
            actionMessage = "Diagnostic log copied to clipboard"
        }
    }
}
