import SwiftUI

public struct HomeView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    
    // Featured tracks with verified YouTube video IDs and artworks
    private let featuredTracks: [Track] = [
        Track(
            id: "34Na4j8AVgA",
            title: "Starboy",
            artist: "The Weeknd ft. Daft Punk",
            album: "Starboy",
            duration: 230,
            artworkURL: URL(string: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"),
            isLossless: true,
            sampleRate: 96000,
            bitDepth: 24
        ),
        Track(
            id: "4NRXx6U8ABQ",
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            duration: 200,
            artworkURL: URL(string: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"),
            isLossless: true,
            sampleRate: 48000,
            bitDepth: 24
        ),
        Track(
            id: "TUVcZfQe-Kw",
            title: "Levitating",
            artist: "Dua Lipa",
            album: "Future Nostalgia",
            duration: 203,
            artworkURL: URL(string: "https://i.ytimg.com/vi/TUVcZfQe-Kw/hqdefault.jpg"),
            isLossless: false
        ),
        Track(
            id: "5NV6Rdv1a3I",
            title: "Get Lucky",
            artist: "Daft Punk ft. Pharrell Williams",
            album: "Random Access Memories",
            duration: 248,
            artworkURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"),
            isLossless: true,
            sampleRate: 192000,
            bitDepth: 24
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // Hero Featured Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FEATURED PLAYLIST")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("Today's Hi-Res Hits")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Bit-perfect lossless streaming with synchronized dynamic lyrics.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Quick Picks Horizontal Carousel
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Picks")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(featuredTracks) { track in
                                    TrackCardView(track: track) {
                                        engine.setQueue(featuredTracks, startIndex: featuredTracks.firstIndex(of: track) ?? 0)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Audio Engine Features Banner
                    HStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bit-Perfect & Lossless")
                                .font(.headline)
                            Text("Automatic DAC sample-rate switching and dynamic lyrics caching enabled.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .padding(.bottom, 80) // Spacing for MiniPlayer
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        BitChordLogoView(size: 28)
                        Text("BitChord")
                            .font(.system(size: 20, weight: .bold))
                    }
                }
            }
        }
    }
}

public struct TrackCardView: View {
    public let track: Track
    public var onPlay: () -> Void
    
    public var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let artURL = track.artworkURL {
                        AsyncImage(url: artURL) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 150, height: 150)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    if track.isLossless {
                        Text(track.audioBadge)
                            .font(.system(size: 8, weight: .bold))
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .padding(6)
                    }
                }
                .frame(width: 150, height: 150)
                
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}
