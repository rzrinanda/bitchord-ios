import SwiftUI

public struct MiniPlayerBar: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    public var onExpand: () -> Void
    
    public init(onExpand: @escaping () -> Void) {
        self.onExpand = onExpand
    }
    
    public var body: some View {
        if let track = engine.currentTrack {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    // Artwork Thumbnail
                    if let artURL = track.artworkURL {
                        AsyncImage(url: artURL) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    } else {
                        BitChordLogoView(size: 44, cornerRadius: 8)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    // Track Information
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controls (Matching Car HU Photo 1 & 2: Loading Spinner / Play / Pause)
                    Button {
                        engine.togglePlayPause()
                    } label: {
                        if engine.status == .loading {
                            ProgressView()
                                .scaleEffect(0.9)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: engine.status == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        engine.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frostedGlass(cornerRadius: 16, opacity: 0.95)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -40 {
                            engine.nextTrack()
                        } else if value.translation.width > 40 {
                            engine.previousTrack()
                        } else if value.translation.height < -30 {
                            onExpand()
                        }
                    }
            )
        }
    }
}
