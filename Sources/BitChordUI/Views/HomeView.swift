import SwiftUI

public struct HomeView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showingAccountMenu: Bool = false
    
    // Top Picks matching user's car Head Unit (Photo 1 & 4)
    private let topPicks: [Track] = [
        Track(
            id: "aL3Z_bA8d38",
            title: "Mimpi Yang Sempurna",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 218,
            artworkURL: URL(string: "https://i.ytimg.com/vi/aL3Z_bA8d38/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "q_k8g6X2jls",
            title: "Kangen",
            artist: "Dewa 19",
            album: "19",
            duration: 312,
            artworkURL: URL(string: "https://i.ytimg.com/vi/q_k8g6X2jls/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "wO0A0XcWy88",
            title: "Separuh Aku",
            artist: "NOAH",
            album: "Seperti Seharusnya",
            duration: 268,
            artworkURL: URL(string: "https://i.ytimg.com/vi/wO0A0XcWy88/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "b_H_y2fHqZs",
            title: "Yang Terdalam",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 198,
            artworkURL: URL(string: "https://i.ytimg.com/vi/b_H_y2fHqZs/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "34Na4j8AVgA",
            title: "Starboy",
            artist: "The Weeknd ft. Daft Punk",
            album: "Starboy",
            duration: 230,
            artworkURL: URL(string: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "5NV6Rdv1a3I",
            title: "Get Lucky",
            artist: "Daft Punk ft. Pharrell Williams",
            album: "Random Access Memories",
            duration: 248,
            artworkURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: - Section: Top Picks for You (Matching Car HU)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Top Picks for You")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(topPicks) { track in
                                    Button {
                                        engine.setQueue(topPicks, startIndex: topPicks.firstIndex(where: { $0.id == track.id }) ?? 0)
                                        library.recordPlayback(track: track)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack(alignment: .bottomTrailing) {
                                                if let artURL = track.artworkURL {
                                                    AsyncImage(url: artURL) { phase in
                                                        if let img = phase.image {
                                                            img.resizable().aspectRatio(contentMode: .fill)
                                                        } else {
                                                            Color.gray.opacity(0.3)
                                                        }
                                                    }
                                                    .frame(width: 170, height: 170)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                } else {
                                                    BitChordLogoView(size: 170, cornerRadius: 14)
                                                }
                                                
                                                // Play badge
                                                Circle()
                                                    .fill(Color.black.opacity(0.65))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Image(systemName: engine.currentTrack?.id == track.id && engine.status == .playing ? "pause.fill" : "play.fill")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                                    .padding(10)
                                            }
                                            
                                            Text(track.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Text(track.artist)
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 170)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // MARK: - Section: Quick Listen
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Putar Cepat")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 8) {
                            ForEach(topPicks.prefix(4)) { track in
                                Button {
                                    engine.setQueue(topPicks, startIndex: topPicks.firstIndex(where: { $0.id == track.id }) ?? 0)
                                    library.recordPlayback(track: track)
                                } label: {
                                    HStack(spacing: 14) {
                                        if let artURL = track.artworkURL {
                                            AsyncImage(url: artURL) { phase in
                                                if let img = phase.image {
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.gray.opacity(0.2)
                                                }
                                            }
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            BitChordLogoView(size: 52, cornerRadius: 10)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(engine.currentTrack?.id == track.id ? .red : .primary)
                                                .lineLimit(1)
                                            Text(track.artist)
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        if engine.currentTrack?.id == track.id {
                                            Image(systemName: "waveform")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.red)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.secondary.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        BitChordLogoView(size: 26, cornerRadius: 6)
                        Text("BitChord")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAccountMenu = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.85))
                                .frame(width: 32, height: 32)
                            Text(accountManager.activeAccount.avatarLetter)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
        }
    }
}
