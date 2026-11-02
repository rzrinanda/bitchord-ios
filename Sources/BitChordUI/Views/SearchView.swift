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
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Curated trending artist / genre tags
    private let trendingTags = [
        "The Weeknd", "Taylor Swift", "Coldplay", "Dua Lipa",
        "Daft Punk", "Billie Eilish", "Bruno Mars", "Olivia Rodrigo",
        "Post Malone", "Kendrick Lamar"
    ]
    
    private let genreCards: [(title: String, colors: [Color])] = [
        ("Pop Hits", [Color.pink, Color.purple]),
        ("Hip-Hop & Rap", [Color.orange, Color.red]),
        ("Rock & Alternative", [Color.blue, Color.indigo]),
        ("Electronic & Dance", [Color.cyan, Color.blue]),
        ("R&B & Soul", [Color.purple, Color.pink]),
        ("Indie & Folk", [Color.green, Color.teal])
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Dedicated Search Bar (Always Visible)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search songs, artists, albums...", text: $query)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: query) { newQuery in
                            debounceSearch(newQuery)
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                            searchResults = []
                            searchTask?.cancel()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                
                // MARK: - Category Filter Chips
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
                    .padding(.bottom, 8)
                }
                
                Divider()
                    .opacity(0.3)
                
                // MARK: - Search Content
                if isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching music catalog...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if query.isEmpty && searchResults.isEmpty {
                    // Empty Search Landing (Discovery / Trending)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            // Trending Tags
                            VStack(alignment: .leading, spacing: 12) {
                                Text("TRENDING SEARCHES")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                    ForEach(trendingTags, id: \.self) { tag in
                                        Button {
                                            query = tag
                                            performSearch()
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "chart.line.uptrend.xyaxis")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.red)
                                                Text(tag)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Browse Genres
                            VStack(alignment: .leading, spacing: 12) {
                                Text("BROWSE GENRES")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(genreCards, id: \.title) { genre in
                                        Button {
                                            query = genre.title
                                            performSearch()
                                        } label: {
                                            ZStack(alignment: .bottomLeading) {
                                                LinearGradient(
                                                    colors: genre.colors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                .frame(height: 75)
                                                .cornerRadius(12)
                                                
                                                Text(genre.title)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(12)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                } else if searchResults.isEmpty && !query.isEmpty {
                    Spacer()
                    ContentUnavailableView.search(text: query)
                    Spacer()
                } else {
                    // Results List
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
                                    } else if track.isLossless {
                                        Text("LOSSLESS")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 3)
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
        }
    }
    
    private func debounceSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await YTMusicClient.shared.search(query: trimmed, filter: selectedFilter.rawValue)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
}
