import SwiftUI

public enum SearchCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case songs = "Songs"
    case videos = "Videos"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
    
    public var id: String { rawValue }
}

public struct SearchView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    
    @State private var query: String = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var selectedCategory: SearchCategory = .all
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showingAccountMenu: Bool = false
    @State private var selectedTrackForMenu: Track? = nil
    @State private var loadingItemId: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Bar & Account Avatar (Matching Car HU Photo 1 & 2)
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
                            .onChange(of: query) { _, newQuery in
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
                .padding(.bottom, 8)
                
                // MARK: - Category Filter Chips (Matching Car HU Photo 1 & 2: All | Songs | Videos | Albums | Artists | Playlists)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                                if !query.isEmpty {
                                    performSearch()
                                } else {
                                    loadDefaultCategoryContent(category)
                                }
                            } label: {
                                Text(category.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedCategory == category ? .white : .secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedCategory == category
                                            ? Color.white.opacity(0.25)
                                            : Color.secondary.opacity(0.12)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                
                Divider()
                    .opacity(0.2)
                
                // MARK: - Content
                if isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching \(selectedCategory.rawValue)...")
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
                            .padding(.top, 12)
                            
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
                                                let idx = library.recentSearches.firstIndex(where: { $0.id == track.id }) ?? 0
                                                engine.setQueue(library.recentSearches, startIndex: idx)
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
                                            .simultaneousGesture(
                                                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                                                    selectedTrackForMenu = track
                                                }
                                            )
                                            
                                            // Delete search item button 'x'
                                            Button {
                                                library.removeRecentSearch(trackId: track.id)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 13, weight: .semibold))
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
                    // Active Search Results (Matching Car HU Photo 2 & 3: Filter header, Rows with 3-dots)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedCategory == .all ? "Results" : selectedCategory.rawValue)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            VStack(spacing: 4) {
                                ForEach(searchResults) { item in
                                    HStack(spacing: 12) {
                                        if item.type == .album || item.type == .playlist {
                                            NavigationLink {
                                                PlaylistOrAlbumDetailView(item: item)
                                            } label: {
                                                searchResultRowContent(for: item)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Button {
                                               handleItemTap(item)
                                            } label: {
                                                searchResultRowContent(for: item)
                                            }
                                            .buttonStyle(.plain)
                                            .simultaneousGesture(
                                                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                                                    selectedTrackForMenu = item.asTrack
                                                }
                                            )
                                        }
                                        
                                        // 3-dots Menu Button (Matching Car HU Photo 2 & 3)
                                        Button {
                                            selectedTrackForMenu = item.asTrack
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 36, height: 36)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button {
                                            engine.insertNextInQueue(item.asTrack)
                                        } label: {
                                            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                        }
                                        Button {
                                            engine.appendToQueue(item.asTrack)
                                        } label: {
                                            Label("Add to Queue", systemImage: "text.badge.plus")
                                        }
                                        Button {
                                            library.toggleLike(track: item.asTrack)
                                        } label: {
                                            Label(library.isLiked(trackId: item.asTrack.id) ? "Unlike" : "Like",
                                                  systemImage: library.isLiked(trackId: item.asTrack.id) ? "star.fill" : "star")
                                        }
                                    }
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
            .sheet(item: $selectedTrackForMenu) { track in
                TrackContextMenuSheet(track: track)
            }
        }
    }
    
    // MARK: - Actions & Helpers
    private func searchResultRowContent(for item: SearchResultItem) -> some View {
        HStack(spacing: 12) {
            // Artwork or Logo
            ZStack {
                if let artURL = item.artworkURL {
                    AsyncImage(url: artURL) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(item.type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                } else {
                    BitChordLogoView(size: 48, cornerRadius: item.type == .artist ? 24 : 8)
                }
                
                if loadingItemId == item.id {
                    Color.black.opacity(0.55)
                        .frame(width: 48, height: 48)
                        .clipShape(item.type == .artist ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isCurrentlyPlaying(item) ? .red : .primary)
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    categoryIcon(for: item.type)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(item.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            
            if isCurrentlyPlaying(item) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.trailing, 4)
            }
        }
    }
    
    private func isCurrentlyPlaying(_ item: SearchResultItem) -> Bool {
        guard let current = engine.currentTrack else { return false }
        if let vId = item.videoId, vId == current.id { return true }
        return item.id == current.id
    }
    
    @ViewBuilder
    private func categoryIcon(for type: SearchResultType) -> some View {
        switch type {
        case .song:
            Image(systemName: "music.note")
        case .video:
            Image(systemName: "play.tv")
        case .album:
            Image(systemName: "opticaldisc")
        case .artist:
            Image(systemName: "person.circle")
        case .playlist:
            Image(systemName: "music.note.list")
        }
    }
    
    private func handleItemTap(_ item: SearchResultItem) {
        switch item.type {
        case .song, .video:
            let track = item.asTrack
            let songsInResults = searchResults.filter { $0.type == .song || $0.type == .video }.map { $0.asTrack }
            let index = songsInResults.firstIndex(where: { $0.id == track.id }) ?? 0
            engine.setQueue(songsInResults.isEmpty ? [track] : songsInResults, startIndex: index)
            library.recordPlayback(track: track)
            library.addRecentSearch(track: track)
            
        case .album, .playlist:
            let idToLoad = item.playlistId ?? item.browseId ?? item.id
            loadingItemId = item.id
            Task {
                var tracks = await YTMusicClient.shared.fetchPlaylistOrAlbumTracks(identifier: idToLoad)
                if tracks.isEmpty {
                    if let searched = try? await YTMusicClient.shared.search(query: "\(item.title) \(item.subtitle)") {
                        tracks = searched
                    }
                }
                await MainActor.run {
                    self.loadingItemId = nil
                    if !tracks.isEmpty {
                        engine.setQueue(tracks, startIndex: 0)
                        library.recordPlayback(track: tracks[0])
                        library.addRecentSearch(track: item.asTrack)
                    } else {
                        let fallback = item.asTrack
                        engine.setQueue([fallback], startIndex: 0)
                        library.recordPlayback(track: fallback)
                    }
                }
            }
            
        case .artist:
            let browseId = item.browseId ?? item.id
            loadingItemId = item.id
            Task {
                var tracks = await YTMusicClient.shared.fetchArtistTracks(browseId: browseId)
                if tracks.isEmpty {
                    if let searched = try? await YTMusicClient.shared.search(query: "\(item.title) popular") {
                        tracks = searched
                    }
                }
                await MainActor.run {
                    self.loadingItemId = nil
                    if !tracks.isEmpty {
                        engine.setQueue(tracks, startIndex: 0)
                        library.recordPlayback(track: tracks[0])
                        library.addRecentSearch(track: item.asTrack)
                    } else {
                        let fallback = item.asTrack
                        engine.setQueue([fallback], startIndex: 0)
                        library.recordPlayback(track: fallback)
                    }
                }
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
        
        isSearching = true
        Task {
            do {
                let results = try await YTMusicClient.shared.searchItems(query: trimmed, filter: selectedCategory.rawValue)
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
    
    private func loadDefaultCategoryContent(_ category: SearchCategory) {
        switch category {
        case .all, .songs:
            searchResults = []
        case .albums:
            fetchCategoryDefaults(query: "Top Albums 2026")
        case .artists:
            fetchCategoryDefaults(query: "Top Artists")
        case .playlists:
            fetchCategoryDefaults(query: "Top Hits Playlist")
        case .videos:
            fetchCategoryDefaults(query: "Top Music Videos")
        }
    }
    
    private func fetchCategoryDefaults(query: String) {
        isSearching = true
        Task {
            do {
                let results = try await YTMusicClient.shared.searchItems(query: query, filter: selectedCategory.rawValue)
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
