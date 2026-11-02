import SwiftUI
import BitChordCore

public struct SyncedLyricsView: View {
    public let track: Track
    @ObservedObject var engine = AudioPlayerEngine.shared
    
    @State private var lyrics: Lyrics?
    @State private var isLoading: Bool = true
    @State private var isSavedLocally: Bool = false
    @State private var autoScrollEnabled: Bool = true
    
    public init(track: Track) {
        self.track = track
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header: Source & Offline Storage Status Pill
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: isSavedLocally ? "externaldrive.fill.badge.checkmark" : "icloud.and.arrow.down")
                        .font(.system(size: 11))
                        .foregroundColor(isSavedLocally ? .green : .secondary)
                    Text(isSavedLocally ? "Stored Locally (Offline)" : "Streaming (Session Only)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSavedLocally ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.2))
                .clipShape(Capsule())
                
                Spacer()
                
                // Manual Download Button
                Button {
                    Task {
                        let success = await LyricsManager.shared.downloadLyricsToStorage(for: track)
                        if success {
                            isSavedLocally = true
                        }
                    }
                } label: {
                    Label(isSavedLocally ? "Saved" : "Save to Storage", systemImage: isSavedLocally ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if isLoading {
                Spacer()
                ProgressView("Fetching lyrics...")
                    .font(.system(size: 14))
                Spacer()
            } else if let lyrics = lyrics, !lyrics.lines.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = lyrics.activeLineIndex(for: engine.currentTime) == index
                                
                                Button {
                                    engine.seek(to: line.timestamp)
                                } label: {
                                    Text(line.text)
                                        .font(.system(size: isActive ? 28 : 22, weight: isActive ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                        .blur(radius: isActive ? 0 : 0.4)
                                        .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 40)
                    }
                    .onChange(of: lyrics.activeLineIndex(for: engine.currentTime)) { _, newIndex in
                        if autoScrollEnabled, let activeIndex = newIndex {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                proxy.scrollTo(activeIndex, anchor: .center)
                            }
                        }
                    }
                }
            } else if let plain = lyrics?.plainLyrics, !plain.isEmpty {
                ScrollView {
                    Text(plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(10)
                        .padding(28)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.4))
                    Text("No lyrics found for this track")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
        }
        .task {
            isLoading = true
            isSavedLocally = await LyricsManager.shared.isLyricsSavedLocally(for: track.id)
            self.lyrics = await LyricsManager.shared.loadLyrics(for: track)
            isSavedLocally = await LyricsManager.shared.isLyricsSavedLocally(for: track.id)
            isLoading = false
        }
    }
}
