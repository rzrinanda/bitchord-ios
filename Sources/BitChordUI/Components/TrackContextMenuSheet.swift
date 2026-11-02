import SwiftUI

public struct TrackContextMenuSheet: View {
    public let track: Track
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPlaylistPicker: Bool = false
    @State private var showingCreatePlaylistAlert: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var actionMessage: String?
    
    public init(track: Track) {
        self.track = track
    }
    
    public var body: some View {
        NavigationStack {
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
                .padding(.top, 20)
                .padding(.bottom, 14)
                
                // Feedback confirmation banner
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
                
                // MARK: - Top Quick Actions (Matching Car HU Photo 3: Like | Dislike | Share)
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
                                .foregroundColor(library.isLiked(trackId: track.id) ? .yellow : .primary)
                            Text("Like")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    
                    // Dislike
                    Button {
                        withAnimation {
                            actionMessage = "Marked as Disliked"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("Dislike")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    
                    // Share
                    ShareLink(item: URL(string: "https://music.youtube.com/watch?v=\(track.id)") ?? URL(string: "https://github.com/rzrinanda/bitchord-ios")!) {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            Text("Share")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                
                // MARK: - Action List (Matching Car HU Photo 3)
                VStack(spacing: 2) {
                    // 1. Convert to video
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Convert to video")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    // 2. Add to playlist
                    Button {
                        showingPlaylistPicker = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Add to playlist")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    // 3. Start radio
                    Button {
                        engine.startRadio(for: track)
                        withAnimation {
                            actionMessage = "Radio started with similar songs"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Start radio")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    // 4. Play next
                    Button {
                        engine.insertNextInQueue(track)
                        withAnimation {
                            actionMessage = "\(track.title) will play next"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Play next")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    // 5. Add to queue
                    Button {
                        engine.appendToQueue(track)
                        withAnimation {
                            actionMessage = "Added to queue"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Add to queue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
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
        }
        .presentationDetents([.medium, .fraction(0.65)])
        .presentationDragIndicator(.visible)
    }
}
