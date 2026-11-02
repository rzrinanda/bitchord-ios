import SwiftUI

public enum MusicSource: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case library = "Library"
    case addons = "Addons"
    
    public var id: String { rawValue }
}

public struct SearchView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var selectedSource: MusicSource = .youtube
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showingAccountMenu: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Bar & Account Avatar (Matching Car HU Photo 2)
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Artists, Songs, Lyrics and More", text: $query)
                            .font(.system(size: 15))
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
                    .clipShape(Capsule())
                    
                    // Avatar Button
                    Button {
                        showingAccountMenu = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.85))
                                .frame(width: 34, height: 34)
                            Text(accountManager.activeAccount.avatarLetter)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                
                // MARK: - Source Selector Pills (YouTube | Library | Addons)
                HStack(spacing: 0) {
                    ForEach(MusicSource.allCases) { source in
                        Button {
                            selectedSource = source
                            if !query.isEmpty {
                                performSearch()
                            }
                        } label: {
                            Text(source.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(selectedSource == source ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSource == source
                                        ? Color.secondary.opacity(0.2)
                                        : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // MARK: - Content
                if isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching \(selectedSource.rawValue)...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if query.isEmpty && searchResults.isEmpty {
                    // Recent Searches Section (Matching Car HU Photo 2)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent searches")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                if !library.recentSearches.isEmpty {
                                    Button("Clear") {
                                        library.clearRecentSearches()
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            if library.recentSearches.isEmpty {
                                Text("No recent searches")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(library.recentSearches) { track in
                                        HStack(spacing: 12) {
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
                                                                Color.gray.opacity(0.3)
                                                            }
                                                        }
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    } else {
                                                        BitChordLogoView(size: 44, cornerRadius: 8)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(track.title)
                                                            .font(.system(size: 15, weight: .semibold))
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                        Text("Lagu • \(track.artist)")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // Delete search item button 'x'
                                            Button {
                                                library.removeRecentSearch(trackId: track.id)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.secondary)
                                                    .padding(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                    }
                } else if searchResults.isEmpty && !query.isEmpty {
                    Spacer()
                    ContentUnavailableView.search(text: query)
                    Spacer()
                } else {
                    // Active Search Results
                    List {
                        ForEach(searchResults) { track in
                            Button {
                                engine.setQueue([track])
                                library.recordPlayback(track: track)
                                library.addRecentSearch(track: track)
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
                                        BitChordLogoView(size: 48, cornerRadius: 8)
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
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
        
        if selectedSource == .library {
            // Search local library
            let lower = trimmed.lowercased()
            self.searchResults = library.likedTracks.filter {
                $0.title.lowercased().contains(lower) || $0.artist.lowercased().contains(lower)
            }
            return
        }
        
        isSearching = true
        Task {
            do {
                let results = try await YTMusicClient.shared.search(query: trimmed)
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
