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
                    // Artwork Thumbnail (Guaranteed Album Art via TrackArtworkView)
                    TrackArtworkView(track: track, size: 44, cornerRadius: 8)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    
                    // Track Information
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            if engine.status == .loading {
                                Text("• Memuat...")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                            } else if engine.currentTime > 0 || engine.duration > 0 {
                                Text("• \(formatTime(engine.currentTime))/\(formatTime(engine.duration > 0 ? engine.duration : track.duration))")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    if engine.availableQualityUpgrade != nil {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                engine.upgradeToAvailableQuality()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.yellow)
                                Text("Upgrade")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
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
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.16).opacity(0.96))
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
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
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
