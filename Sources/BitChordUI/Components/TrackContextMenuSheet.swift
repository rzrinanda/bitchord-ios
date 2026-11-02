import SwiftUI

public struct TrackContextMenuSheet: View {
    public let track: Track
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPlaylistPicker: Bool = false
    @State private var toastMessage: String?
    
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
                
                // MARK: - Top Quick Actions (Matching Car HU Photo 3: Like | Dislike | Share)
                HStack(spacing: 0) {
                    // Like
                    Button {
                        library.toggleLike(track: track)
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
                        // Dislike removes from recommendations
                        dismiss()
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
                        // Switch to video / canvas mode if available
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
                        // Radio plays track and automatically triggers similar song suggestions
                        engine.setQueue([track])
                        dismiss()
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
                        dismiss()
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
                        dismiss()
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
            .sheet(isPresented: $showingPlaylistPicker) {
                NavigationStack {
                    List {
                        ForEach(library.userPlaylists) { playlist in
                            Button {
                                library.addTrackToPlaylist(playlistId: playlist.id, track: track)
                                showingPlaylistPicker = false
                                dismiss()
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
                            }
                        }
                    }
                    .navigationTitle("Select Playlist")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingPlaylistPicker = false }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .fraction(0.65)])
        .presentationDragIndicator(.visible)
    }
}
