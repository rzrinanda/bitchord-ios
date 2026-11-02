import SwiftUI

public enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    
    public var id: String { rawValue }
}

public struct SearchView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var selectedFilter: SearchFilter = .all
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchFilter.allCases) { filter in
                            Button {
                                selectedFilter = filter
                                performSearch()
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedFilter == filter ? Color.red : Color.secondary.opacity(0.15))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                if isSearching {
                    Spacer()
                    ProgressView("Searching catalog...")
                        .padding()
                    Spacer()
                } else if searchResults.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(searchResults) { track in
                            Button {
                                engine.setQueue([track])
                                library.recordPlayback(track: track)
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
                            .contextMenu {
                                Button {
                                    engine.insertNextInQueue(track)
                                } label: {
                                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                }
                                Button {
                                    library.toggleLike(track: track)
                                } label: {
                                    Label(library.isLiked(trackId: track.id) ? "Unlike" : "Like Song",
                                          systemImage: library.isLiked(trackId: track.id) ? "heart.slash" : "heart.fill")
                                }
                                Button {
                                    Task {
                                        _ = try? await DownloadManager.shared.downloadTrack(track: track)
                                    }
                                } label: {
                                    Label("Download to Device", systemImage: "arrow.down.circle")
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
