import SwiftUI

public struct SongInfoDialog: View {
    public let track: Track
    public var onDismiss: () -> Void
    
    @State private var songInfo: SongInfo? = nil
    @State private var isLoading: Bool = true
    
    public init(track: Track, onDismiss: @escaping () -> Void) {
        self.track = track
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Dimmed scrim background
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Centered UIAlertController-style card (Matching Car HU Photo 1)
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Song Info")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                    
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Properties List
                VStack(spacing: 0) {
                    infoRow(label: "Album", value: songInfo?.album ?? (track.album.isEmpty || track.album == "YouTube Music" ? "-" : track.album))
                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)
                    
                    infoRow(label: "Release date", value: songInfo?.releaseDate ?? "-")
                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)
                    
                    infoRow(label: "Plays / views", value: songInfo?.views ?? "-")
                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)
                    
                    infoRow(label: "Likes", value: songInfo?.likes ?? "-")
                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)
                    
                    infoRow(label: "Comments", value: songInfo?.comments ?? "-")
                }
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Done Button
                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 310)
            .background(Color(red: 0.14, green: 0.15, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        }
        .task {
            let info = await YTMusicClient.shared.fetchSongInfo(for: track)
            await MainActor.run {
                self.songInfo = info
                self.isLoading = false
            }
        }
    }
    
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
            
            Spacer()
            
            if isLoading && value == "-" {
                ProgressView()
                    .scaleEffect(0.65)
                    .tint(.white.opacity(0.7))
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
