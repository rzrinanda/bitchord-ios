import SwiftUI

public struct BitChordLogoView: View {
    public var size: CGFloat
    public var cornerRadius: CGFloat
    
    public init(size: CGFloat = 40, cornerRadius: CGFloat? = nil) {
        self.size = size
        self.cornerRadius = cornerRadius ?? (size * 0.22)
    }
    
    public var body: some View {
        ZStack {
            // Vibrant BitChord Apple Music gradient tile
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.15, blue: 0.35),
                    Color(red: 0.80, green: 0.05, blue: 0.40),
                    Color(red: 0.45, green: 0.02, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.red.opacity(0.3), radius: size * 0.15, x: 0, y: size * 0.08)
            
            // Stylized BitChord double-stem connected chord glyph
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Left Note Head
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: w * 0.26, height: h * 0.18)
                        .rotationEffect(.degrees(-20))
                        .position(x: w * 0.35, y: h * 0.68)
                    
                    // Right Note Head
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: w * 0.26, height: h * 0.18)
                        .rotationEffect(.degrees(-20))
                        .position(x: w * 0.68, y: h * 0.58)
                    
                    // Stems
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.06, height: h * 0.42)
                        .position(x: w * 0.44, y: h * 0.48)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.06, height: h * 0.32)
                        .position(x: w * 0.77, y: h * 0.43)
                    
                    // Beams
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.39, height: h * 0.08)
                        .position(x: w * 0.605, y: h * 0.28)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: w * 0.39, height: h * 0.06)
                        .position(x: w * 0.605, y: h * 0.38)
                    
                    // Soundwave bars
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: w * 0.04, height: h * 0.20)
                        .position(x: w * 0.18, y: h * 0.52)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: w * 0.035, height: h * 0.10)
                        .position(x: w * 0.11, y: h * 0.52)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Reusable album artwork component that automatically resolves high-resolution cover art
/// when a track or search item has missing, HTTP, or ISP-blocked artwork URLs.
public struct TrackArtworkView: View {
    public let trackId: String?
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public let size: CGFloat
    public let cornerRadius: CGFloat
    public let isCircular: Bool
    
    @State private var resolvedURL: URL? = nil
    @State private var didFailInitialURL: Bool = false
    
    public init(
        trackId: String? = nil,
        title: String,
        artist: String,
        album: String = "",
        artworkURL: URL?,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
    }
    
    public init(
        track: Track,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 8,
        isCircular: Bool = false
    ) {
        self.init(
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkURL: track.artworkURL,
            size: size,
            cornerRadius: cornerRadius,
            isCircular: isCircular
        )
    }
    
    private var activeURL: URL? {
        if let resolved = resolvedURL {
            return resolved
        }
        if didFailInitialURL {
            return nil
        }
        if let initial = artworkURL, !ArtworkResolver.shouldResolveReplacement(for: initial) {
            return initial
        }
        return nil
    }
    
    public var body: some View {
        ZStack {
            if let url = activeURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        BitChordLogoView(size: size, cornerRadius: isCircular ? size / 2 : cornerRadius)
                            .task(id: "fail_\(url.absoluteString)") {
                                await triggerFallbackResolution(forceRefresh: true)
                            }
                    case .empty:
                        BitChordLogoView(size: size, cornerRadius: isCircular ? size / 2 : cornerRadius)
                    @unknown default:
                        BitChordLogoView(size: size, cornerRadius: isCircular ? size / 2 : cornerRadius)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(isCircular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            } else {
                BitChordLogoView(size: size, cornerRadius: isCircular ? size / 2 : cornerRadius)
                    .clipShape(isCircular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            }
        }
        .frame(width: size, height: size)
        .task(id: "\(trackId ?? "")|\(title)|\(artist)|\(artworkURL?.absoluteString ?? "")") {
            if ArtworkResolver.shouldResolveReplacement(for: artworkURL) {
                await triggerFallbackResolution(forceRefresh: true)
            } else if let cached = await ArtworkResolver.shared.cachedArtworkURL(title: title, artist: artist, trackId: trackId) {
                if artworkURL == nil {
                    self.resolvedURL = cached
                }
            }
        }
    }
    
    @MainActor
    private func triggerFallbackResolution(forceRefresh: Bool) async {
        self.didFailInitialURL = true
        if let replacement = await ArtworkResolver.shared.resolveArtworkURL(
            title: title,
            artist: artist,
            album: album,
            trackId: trackId,
            existingURL: nil,
            forceRefresh: forceRefresh
        ) {
            self.resolvedURL = replacement
            if let tid = trackId, !tid.isEmpty {
                LibraryDatabase.shared.updateTrackArtwork(trackId: tid, title: title, artworkURL: replacement)
            }
        }
    }
}
