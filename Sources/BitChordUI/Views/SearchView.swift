import SwiftUI

public enum SearchSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case youtube = "YouTube"
    case library = "Library"
    case addons = "Addons"
    
    public var id: String { rawValue }
}

public enum SearchCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case songs = "Songs"
    case videos = "Videos"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
    case downloaded = "Downloaded"
    
    public var id: String { rawValue }
    
    public static func categories(for source: SearchSource) -> [SearchCategory] {
        switch source {
        case .youtube:
            return [.all, .songs, .videos, .albums, .artists, .playlists]
        case .library:
            return [.all, .songs, .playlists, .albums, .artists, .downloaded]
        case .addons:
            return [.all, .songs, .albums, .artists]
        }
    }
}

private struct BrowseCategoryCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let imageURL: URL?
}

public struct SearchView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var accountManager = AccountManager.shared
    @ObservedObject var settings = BitChordSettings.shared
    
    @State private var query: String = ""
    @State private var selectedSource: SearchSource = .youtube
    @State private var selectedCategory: SearchCategory = .all
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showingAccountMenu: Bool = false
    @State private var showingAddAddonSheet: Bool = false
    @State private var selectedTrackForMenu: Track? = nil
    @State private var loadingItemId: String? = nil
    
    private let browseCategories: [BrowseCategoryCard] = [
        BrowseCategoryCard(
            title: "Hits Cafe",
            subtitle: "Chill",
            gradientColors: [Color(red: 0.35, green: 0.28, blue: 0.20), Color(red: 0.18, green: 0.14, blue: 0.10)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=400&q=80")
        ),
        BrowseCategoryCard(
            title: "Commute",
            subtitle: "Feel-good music",
            gradientColors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.12, green: 0.12, blue: 0.14)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80")
        ),
        BrowseCategoryCard(
            title: "Energize",
            subtitle: "Workout & Vibes",
            gradientColors: [Color(red: 0.35, green: 0.18, blue: 0.40), Color(red: 0.12, green: 0.15, blue: 0.35)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80")
        ),
        BrowseCategoryCard(
            title: "Sunshine Indie",
            subtitle: "Feel good",
            gradientColors: [Color(red: 0.45, green: 0.30, blue: 0.15), Color(red: 0.25, green: 0.15, blue: 0.08)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=400&q=80")
        ),
        BrowseCategoryCard(
            title: "Acoustic Chill",
            subtitle: "Relax",
            gradientColors: [Color(red: 0.18, green: 0.30, blue: 0.32), Color(red: 0.10, green: 0.18, blue: 0.20)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80")
        ),
        BrowseCategoryCard(
            title: "Top Hits",
            subtitle: "Party & Dance",
            gradientColors: [Color(red: 0.42, green: 0.15, blue: 0.22), Color(red: 0.20, green: 0.08, blue: 0.12)],
            imageURL: URL(string: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80")
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Bar & Account Avatar
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Artists, Songs, Lyrics, and More", text: $query)
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
                                selectedCategory = .all
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
                .padding(.bottom, 6)
                
                // MARK: - Source Selector Bar: [ YouTube ] [ Library ] [ Addons ] (Matching Reference Screenshot)
                HStack {
                    ForEach(SearchSource.allCases) { source in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedSource = source
                                let validCats = SearchCategory.categories(for: source)
                                if !validCats.contains(selectedCategory) {
                                    selectedCategory = .all
                                }
                            }
                            if !query.isEmpty {
                                performSearch()
                            }
                        } label: {
                            Text(source.rawValue)
                                .font(.system(size: 14, weight: selectedSource == source ? .semibold : .medium))
                                .foregroundColor(selectedSource == source ? .white : .secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 7)
                                .background(
                                    selectedSource == source
                                        ? Color.white.opacity(0.24)
                                        : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        if source != SearchSource.allCases.last {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
                
                // MARK: - Category Filter Chips (Hidden before search, shown after searching to filter results)
                if !query.isEmpty || !searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchCategory.categories(for: selectedSource)) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategory = category
                                    }
                                    if !query.isEmpty {
                                        performSearch()
                                    }
                                } label: {
                                    Text(category.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(selectedCategory == category ? .white : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
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
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                    .opacity(0.15)
                
                // MARK: - Content Area
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
                    // Empty Query State
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            // If Addons is selected but user has no active addons configured
                            if selectedSource == .addons && settings.addonSources.filter({ $0.isEnabled }).isEmpty {
                                addonEmptyPromptView
                            } else {
                                // MARK: - Recently Searched Section (Matching Reference Screenshot)
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Recently Searched")
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
                                    } else {
                                        VStack(spacing: 8) {
                                            ForEach(library.recentSearches.prefix(4)) { track in
                                                recentSearchCard(for: track)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                
                                // MARK: - Browse Categories Section (Matching Reference Screenshot 2-Column Grid)
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Browse Categories")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                    
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)
                                        ],
                                        spacing: 12
                                    ) {
                                        ForEach(browseCategories) { item in
                                            NavigationLink {
                                                CategoryPlaylistsBrowserView(categoryTitle: item.title)
                                            } label: {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: item.gradientColors,
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(height: 104)
                                                    .overlay {
                                                        if let url = item.imageURL {
                                                            AsyncImage(url: url) { phase in
                                                                if let img = phase.image {
                                                                    img.resizable()
                                                                        .scaledToFill()
                                                                        .frame(height: 104)
                                                                        .clipped()
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .overlay {
                                                        LinearGradient(
                                                            colors: [Color.black.opacity(0.72), Color.black.opacity(0.35)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    }
                                                    .overlay(alignment: .topLeading) {
                                                        VStack(alignment: .leading, spacing: 3) {
                                                            Text(item.title)
                                                                .font(.system(size: 16, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .lineLimit(1)
                                                            Text(item.subtitle)
                                                                .font(.system(size: 12, weight: .medium))
                                                                .foregroundColor(.white.opacity(0.85))
                                                                .lineLimit(1)
                                                        }
                                                        .padding(12)
                                                    }
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, engine.currentTrack != nil ? 140 : 70)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else if searchResults.isEmpty && !query.isEmpty {
                    Spacer()
                    if selectedSource == .addons && settings.addonSources.filter({ $0.isEnabled }).isEmpty {
                        addonEmptyPromptView
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                    Spacer()
                } else {
                    // Active Search Results
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedCategory == .all ? "\(selectedSource.rawValue) Results" : selectedCategory.rawValue)
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
                                        }
                                        
                                        // 3-dots Menu Button
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
                        }
                        .padding(.bottom, engine.currentTrack != nil ? 140 : 70)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAccountMenu) {
                AccountMenuSheet()
            }
            .sheet(isPresented: $showingAddAddonSheet) {
                AddAddonSheet()
            }
            .sheet(item: $selectedTrackForMenu) { track in
                TrackContextMenuSheet(track: track)
            }
        }
    }
    
    // MARK: - Recently Searched Card View (Matches Screenshot Card Style)
    private func recentSearchCard(for track: Track) -> some View {
        HStack(spacing: 12) {
            Button {
                let idx = library.recentSearches.firstIndex(where: { $0.id == track.id }) ?? 0
                engine.setQueue(library.recentSearches, startIndex: idx)
                library.recordPlayback(track: track)
            } label: {
                HStack(spacing: 12) {
                    TrackArtworkView(track: track, size: 48, cornerRadius: 8)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("\(track.artist) • Song")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button {
                library.removeRecentSearch(trackId: track.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Addon Empty Prompt
    private var addonEmptyPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 44))
                .foregroundColor(.cyan)
            Text("No Addon Connected")
                .font(.title3.bold())
            Text("Connect a SoundFean, Qobuz, or BitPerfect addon server to stream Hi-Res lossless audio directly.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showingAddAddonSheet = true
            } label: {
                Text("Connect an Addon")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.cyan)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Search Result Row Content
    private func searchResultRowContent(for item: SearchResultItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                TrackArtworkView(
                    trackId: item.videoId ?? item.id,
                    title: item.title,
                    artist: item.artist ?? item.subtitle,
                    album: item.album ?? "",
                    artworkURL: item.artworkURL,
                    size: 48,
                    cornerRadius: 8,
                    isCircular: item.type == .artist
                )
                
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
    
    // MARK: - Item Tap Action (Instant source-specific playback)
    private func handleItemTap(_ item: SearchResultItem) {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        
        switch item.type {
        case .song, .video:
            var track = item.asTrack
            track.source = selectedSource == .library ? .library : (selectedSource == .addons ? .addon : .youtube)
            track.sourceId = item.sourceId
            
            // If from Library source, attach local file streamURL if exists for instant 0ms playback
            if track.source == .library {
                if let localURL = DownloadManager.shared.getLocalFileURL(for: track.id) {
                    track.streamURL = localURL
                } else if let scanned = LocalMusicScanner.shared.tracks.first(where: { $0.id == track.id }),
                          let localURL = scanned.streamURL {
                    track.streamURL = localURL
                }
            }
            
            let songsInResults = searchResults.filter { $0.type == .song || $0.type == .video }.map { resItem -> Track in
                var t = resItem.asTrack
                t.source = track.source
                t.sourceId = resItem.sourceId ?? track.sourceId
                if t.source == .library {
                    if let localURL = DownloadManager.shared.getLocalFileURL(for: t.id) {
                        t.streamURL = localURL
                    } else if let scanned = LocalMusicScanner.shared.tracks.first(where: { $0.id == t.id }),
                              let localURL = scanned.streamURL {
                        t.streamURL = localURL
                    }
                }
                return t
            }
            
            let index = songsInResults.firstIndex(where: { $0.id == track.id }) ?? 0
            engine.setQueue(songsInResults.isEmpty ? [track] : songsInResults, startIndex: index)
            library.recordPlayback(track: track)
            library.addRecentSearch(track: track)
            
        case .album, .playlist:
            let idToLoad = item.playlistId ?? item.browseId ?? item.id
            loadingItemId = item.id
            Task {
                var tracks: [Track] = []
                if selectedSource == .library {
                    // Local playlist or album
                    if let p = library.userPlaylists.first(where: { $0.id == idToLoad }) {
                        tracks = p.tracks
                    } else {
                        tracks = LocalMusicScanner.shared.tracks.filter { $0.album == item.title }
                    }
                } else {
                    tracks = await YTMusicClient.shared.fetchPlaylistOrAlbumTracks(identifier: idToLoad)
                    if tracks.isEmpty {
                        if let searched = try? await YTMusicClient.shared.search(query: "\(item.title) \(item.subtitle)") {
                            tracks = searched
                        }
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
                var tracks: [Track] = []
                if selectedSource == .library {
                    tracks = LocalMusicScanner.shared.tracks.filter { $0.artist.localizedCaseInsensitiveContains(item.title) }
                } else {
                    tracks = await YTMusicClient.shared.fetchArtistTracks(browseId: browseId)
                    if tracks.isEmpty {
                        if let searched = try? await YTMusicClient.shared.search(query: "\(item.title) popular") {
                            tracks = searched
                        }
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
    
    // MARK: - Search Execution & Debounce
    private func debounceSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            selectedCategory = .all
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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
        
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        
        isSearching = true
        Task {
            switch selectedSource {
            case .youtube:
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
                
            case .library:
                let results = await searchLibrary(query: trimmed, category: selectedCategory)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
                
            case .addons:
                let results = await AddonService.shared.searchAddons(query: trimmed, filter: selectedCategory.rawValue)
                let filtered: [SearchResultItem]
                if selectedCategory == .all {
                    filtered = results
                } else if selectedCategory == .songs {
                    filtered = results.filter { $0.type == .song }
                } else if selectedCategory == .albums {
                    filtered = results.filter { $0.type == .album }
                } else if selectedCategory == .artists {
                    filtered = results.filter { $0.type == .artist }
                } else {
                    filtered = results
                }
                await MainActor.run {
                    self.searchResults = filtered
                    self.isSearching = false
                }
            }
        }
    }
    
    // MARK: - Local Library Search
    @MainActor
    private func searchLibrary(query: String, category: SearchCategory) async -> [SearchResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var pool: [Track] = []
        let downloaded = await DownloadManager.shared.getDownloadedTracks()
        pool.append(contentsOf: downloaded)
        pool.append(contentsOf: LocalMusicScanner.shared.tracks)
        pool.append(contentsOf: library.likedTracks)
        pool.append(contentsOf: library.recentTracks)
        
        var seenIds = Set<String>()
        var uniqueTracks: [Track] = []
        for t in pool {
            if !seenIds.contains(t.id) {
                seenIds.insert(t.id)
                uniqueTracks.append(t)
            }
        }
        
        let matchedTracks = uniqueTracks.filter { t in
            if trimmed.isEmpty { return true }
            return t.title.lowercased().contains(trimmed) ||
                   t.artist.lowercased().contains(trimmed) ||
                   t.album.lowercased().contains(trimmed)
        }
        
        var results: [SearchResultItem] = []
        
        // Playlists
        if category == .all || category == .playlists {
            let matchedPlaylists = library.userPlaylists.filter { p in
                if trimmed.isEmpty { return true }
                return p.title.lowercased().contains(trimmed)
            }
            for p in matchedPlaylists {
                results.append(
                    SearchResultItem(
                        id: p.id,
                        title: p.title,
                        subtitle: "\(p.tracks.count) songs • Library Playlist",
                        type: .playlist,
                        playlistId: p.id,
                        source: .library
                    )
                )
            }
        }
        
        // Songs
        if category == .all || category == .songs || category == .downloaded {
            for t in matchedTracks {
                let isDl = DownloadManager.shared.getLocalFileURL(for: t.id) != nil || t.streamURL?.isFileURL == true
                if category == .downloaded && !isDl { continue }
                
                let subtitleBadge = isDl ? "Downloaded • \(t.artist)" : "Library • \(t.artist)"
                results.append(
                    SearchResultItem(
                        id: t.id,
                        title: t.title,
                        subtitle: subtitleBadge,
                        type: .song,
                        artist: t.artist,
                        album: t.album,
                        artworkURL: t.artworkURL,
                        duration: t.duration,
                        streamURL: t.streamURL ?? DownloadManager.shared.getLocalFileURL(for: t.id),
                        source: .library
                    )
                )
            }
        }
        
        // Albums
        if category == .all || category == .albums {
            let albumsGrouped = Dictionary(grouping: matchedTracks.filter { !$0.album.isEmpty && $0.album != "Unknown Album" }) { $0.album }
            for (albumName, albumTracks) in albumsGrouped {
                let art = albumTracks.first?.artworkURL
                let artist = albumTracks.first?.artist ?? "Various Artists"
                results.append(
                    SearchResultItem(
                        id: "local_album_\(albumName)",
                        title: albumName,
                        subtitle: "Album • \(artist)",
                        type: .album,
                        artist: artist,
                        album: albumName,
                        artworkURL: art,
                        browseId: "local_album_\(albumName)",
                        source: .library
                    )
                )
            }
        }
        
        // Artists
        if category == .all || category == .artists {
            let artistsGrouped = Dictionary(grouping: matchedTracks.filter { !$0.artist.isEmpty && $0.artist != "Unknown Artist" }) { $0.artist }
            for (artistName, artistTracks) in artistsGrouped {
                let art = artistTracks.first?.artworkURL
                results.append(
                    SearchResultItem(
                        id: "local_artist_\(artistName)",
                        title: artistName,
                        subtitle: "Artist • \(artistTracks.count) tracks",
                        type: .artist,
                        artist: artistName,
                        artworkURL: art,
                        browseId: "local_artist_\(artistName)",
                        source: .library
                    )
                )
            }
        }
        
        return results
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
        case .downloaded:
            Task {
                let res = await searchLibrary(query: "", category: .downloaded)
                await MainActor.run {
                    self.searchResults = res
                }
            }
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
