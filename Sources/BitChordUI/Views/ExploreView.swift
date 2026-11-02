import SwiftUI

public struct ExploreView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @State private var showingAccountMenu: Bool = false
    
    // Curated Indonesian & Global charts
    private let charts: [(title: String, subtitle: String, image: String, color: Color)] = [
        ("Top 50 Indonesia", "Lagu terpopuler minggu ini", "flame.fill", .red),
        ("Top 50 Global", "Hits internasional teratas", "globe", .blue),
        ("Nostalgia Indonesia", "Lagu legendaris 90s & 2000s", "music.note.tv.fill", .orange),
        ("Indie & Senja", "Karya musisi independen tanah air", "guitars.fill", .purple)
    ]
    
    // Explore featured Indonesian songs matching user's taste (NOAH, Dewa 19, etc.)
    private let exploreSongs: [Track] = [
        Track(
            id: "yt_mpy_sempurna",
            title: "Mimpi Yang Sempurna",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 218,
            artworkURL: URL(string: "https://i.ytimg.com/vi/aL3Z_bA8d38/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "yt_kangen_d19",
            title: "Kangen",
            artist: "Dewa 19",
            album: "19",
            duration: 312,
            artworkURL: URL(string: "https://i.ytimg.com/vi/q_k8g6X2jls/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "yt_separuh_aku",
            title: "Separuh Aku",
            artist: "NOAH",
            album: "Seperti Seharusnya",
            duration: 268,
            artworkURL: URL(string: "https://i.ytimg.com/vi/wO0A0XcWy88/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "yt_roman_picisan",
            title: "Roman Picisan",
            artist: "Dewa 19",
            album: "Bintang Lima",
            duration: 243,
            artworkURL: URL(string: "https://i.ytimg.com/vi/m9g4Q6Y3kYs/hqdefault.jpg"),
            isLossless: true
        ),
        Track(
            id: "yt_yang_terdalam",
            title: "Yang Terdalam",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 198,
            artworkURL: URL(string: "https://i.ytimg.com/vi/b_H_y2fHqZs/hqdefault.jpg"),
            isLossless: true
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // Charts Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Charts & Tangga Lagu")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(charts, id: \.title) { chart in
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(chart.color.gradient)
                                            Image(systemName: chart.image)
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                        .frame(width: 140, height: 140)
                                        
                                        Text(chart.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(chart.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 140)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Trending Tracks List
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Trending Musik Indonesia")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 6) {
                            ForEach(exploreSongs) { track in
                                Button {
                                    engine.setQueue(exploreSongs, startIndex: exploreSongs.firstIndex(where: { $0.id == track.id }) ?? 0)
                                    library.recordPlayback(track: track)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let artURL = track.artworkURL {
                                            AsyncImage(url: artURL) { phase in
                                                if let img = phase.image {
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.gray.opacity(0.3)
                                                }
                                            }
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            BitChordLogoView(size: 48, cornerRadius: 8)
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
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.red)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.secondary.opacity(0.7))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAccountMenu = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.85))
                                .frame(width: 32, height: 32)
                            Text(AccountManager.shared.activeAccount.avatarLetter)
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
