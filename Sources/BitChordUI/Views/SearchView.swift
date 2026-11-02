import SwiftUI

public struct SearchView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack {
                if isSearching {
                    ProgressView("Searching BitChord catalog...")
                        .padding()
                } else if searchResults.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(searchResults) { track in
                            Button {
                                engine.setQueue([track])
                            } label: {
                                HStack(spacing: 12) {
                                    if let artURL = track.artworkURL {
                                        AsyncImage(url: artURL) { phase in
                                            if let img = phase.image {
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Color.gray.opacity(0.2)
                                            }
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.2))
                                            Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 48, height: 48)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if track.isLossless {
                                        Text("LOSSLESS")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(4)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, Artists, Albums, Playlists")
            .onSubmit(of: .search) {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            do {
                self.searchResults = try await YTMusicClient.shared.search(query: query)
            } catch {
                self.searchResults = []
            }
            self.isSearching = false
        }
    }
}
