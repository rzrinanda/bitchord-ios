import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLyrics: Bool = false
    @State private var showingQueue: Bool = false
    @State private var showingAudioPipeline: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0
    @State private var selectedTrackForMenu: Track? = nil
    @State private var currentLyricLine: String? = nil
    @State private var loadedLyrics: Lyrics? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            DynamicBackgroundGradient(accentColor: .blue)
            
            if let track = engine.currentTrack {
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Audio Quality Badge -> Opens Audio Pipeline
                        Button {
                            showingAudioPipeline = true
                        } label: {
                            Text(track.audioBadge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            showingQueue.toggle()
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    if showingLyrics {
                        SyncedLyricsView(track: track)
                            .transition(.opacity)
                    } else {
                        // Artwork & Track Details
                        Spacer()
                        
                        ZStack {
                            if let artURL = track.artworkURL {
                                AsyncImage(url: artURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.white.opacity(0.1)
                                    }
                                }
                                .frame(width: 290, height: 290)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                            } else {
                                BitChordLogoView(size: 290, cornerRadius: 24)
                                    .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                            }
                        }
                        .scaleEffect(engine.status == .playing ? 1.0 : 0.88)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.status)
                        
                        Spacer()
                        
                        // Track Info Row
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(track.artist)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                    
                                    if !track.album.isEmpty && track.album != "YouTube Music" && track.album.lowercased() != track.title.lowercased() && track.album.lowercased() != track.artist.lowercased() {
                                        Text("•")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.4))
                                        
                                        Text(track.album)
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.white.opacity(0.65))
                                            .lineLimit(1)
                                    }
                                }
                                
                                // Synchronized Lyric / Instrumental Snippet (Matching Reference Video Frame 001/010)
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showingLyrics.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if let line = currentLyricLine, !line.isEmpty {
                                            Text(line)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white.opacity(0.85))
                                                .lineLimit(1)
                                        } else {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))
                                            Text("Instrumental")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white.opacity(0.75))
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    .padding(.top, 2)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    library.toggleLike(track: track)
                                } label: {
                                    Image(systemName: library.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 22))
                                        .foregroundColor(library.isLiked(trackId: track.id) ? .red : .white.opacity(0.85))
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    selectedTrackForMenu = track
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                    }
                    
                    // Scrubber Bar
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? dragSliderValue : engine.currentTime },
                                set: { newValue in
                                    dragSliderValue = newValue
                                    isDraggingSlider = true
                                }
                            ),
                            in: 0...max(1, engine.duration),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing {
                                    engine.seek(to: dragSliderValue)
                                }
                            }
                        )
                        .tint(.white)
                        
                        HStack {
                            Text(formatTime(isDraggingSlider ? dragSliderValue : engine.currentTime))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            // Audio Pipeline Trigger Pill (Matching User Reference Video)
                            Button {
                                showingAudioPipeline = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 11))
                                    Text(track.audioBadge.capitalized)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Text("-\(formatTime(max(0, engine.duration - (isDraggingSlider ? dragSliderValue : engine.currentTime))))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    
                    // Main Playback Controls
                    HStack(spacing: 44) {
                        Button {
                            engine.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.togglePlayPause()
                        } label: {
                            if engine.status == .loading {
                                ProgressView()
                                    .scaleEffect(1.6)
                                    .tint(.white)
                                    .frame(width: 68, height: 68)
                            } else {
                                Image(systemName: engine.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 68))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 20)
                    
                    // BitChord 3-Mode Pill: [ Shuffle | Repeat | Loop/AutoPlay ] (Matching Car HU Photo 4)
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            // Shuffle Button
                            Button {
                                engine.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(engine.shuffleMode == .on ? .white : .white.opacity(0.45))
                                    .frame(width: 54, height: 36)
                                    .background(engine.shuffleMode == .on ? Color.red.opacity(0.85) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .frame(height: 18)
                                .background(Color.white.opacity(0.2))
                            
                            // Repeat Button (Off -> All -> One -> Off)
                            Button {
                                engine.cycleRepeatMode()
                            } label: {
                                Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(engine.repeatMode != .off ? .white : .white.opacity(0.45))
                                    .frame(width: 54, height: 36)
                                    .background(engine.repeatMode != .off ? Color.red.opacity(0.85) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .frame(height: 18)
                                .background(Color.white.opacity(0.2))
                            
                            // Loop / AutoPlay Button (∞)
                            Button {
                                engine.toggleAutoPlay()
                            } label: {
                                Image(systemName: "infinity")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(engine.isAutoPlayEnabled ? .white : .white.opacity(0.45))
                                    .frame(width: 54, height: 36)
                                    .background(engine.isAutoPlayEnabled ? Color.red.opacity(0.85) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(3)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        
                        Text("This phone")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 22)
                    
                    // Bottom Action Row
                    HStack(spacing: 52) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingLyrics.toggle()
                            }
                        } label: {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 20))
                                .foregroundColor(showingLyrics ? .white : .white.opacity(0.55))
                                .padding(8)
                                .background(showingLyrics ? Color.white.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            #if canImport(AVKit)
                            // Route picker
                            #endif
                        } label: {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingQueue.toggle()
                        } label: {
                            Image(systemName: "list.dash")
                                .font(.system(size: 20))
                                .foregroundColor(showingQueue ? .white : .white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheetView()
        }
        .sheet(item: $selectedTrackForMenu) { track in
            TrackContextMenuSheet(track: track)
        }
        .sheet(isPresented: $showingAudioPipeline) {
            if let track = engine.currentTrack {
                AudioPipelineSheet(track: track)
            }
        }
        .task(id: engine.currentTrack?.id) {
            guard let track = engine.currentTrack else {
                currentLyricLine = nil
                loadedLyrics = nil
                return
            }
            let l = await LyricsManager.shared.loadLyrics(for: track)
            self.loadedLyrics = l
            if let l = l {
                if let idx = l.activeLineIndex(for: engine.currentTime), idx < l.lines.count {
                    currentLyricLine = l.lines[idx].text
                } else {
                    currentLyricLine = l.lines.first?.text
                }
            } else {
                currentLyricLine = nil
            }
        }
        .onChange(of: engine.currentTime) { _, newTime in
            if let l = loadedLyrics {
                if let idx = l.activeLineIndex(for: newTime), idx < l.lines.count {
                    currentLyricLine = l.lines[idx].text
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

public struct QueueSheetView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var dynamicAutoPlayTracks: [Track] = []
    @State private var selectedTrackForMenu: Track? = nil
    
    // Default fallback if offline
    private let defaultFallbackSuggestions: [Track] = [
        Track(
            id: "R6f_7G71p_w",
            title: "Starlight",
            artist: "Muse",
            album: "Black Holes and Revelations",
            duration: 240,
            artworkURL: URL(string: "https://i.ytimg.com/vi/R6f_7G71p_w/hqdefault.jpg")
        ),
        Track(
            id: "KwhjlNvF-4Q",
            title: "Hysteria",
            artist: "Muse",
            album: "Absolution",
            duration: 227,
            artworkURL: URL(string: "https://i.ytimg.com/vi/KwhjlNvF-4Q/hqdefault.jpg")
        )
    ]
    
    public init() {}
    
    private func loadAutoPlayRecommendations() {
        guard let current = engine.currentTrack else { return }
        Task {
            let tracks = await YTMusicClient.shared.fetchRadioTracks(for: current)
            await MainActor.run {
                self.dynamicAutoPlayTracks = tracks
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header (Matching Car HU Photo 4)
                HStack {
                    Text("Queue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    
                    // BitChord 3-Mode Quick Pill
                    HStack(spacing: 0) {
                        Button {
                            engine.toggleShuffle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(engine.shuffleMode == .on ? .white : .secondary)
                                .frame(width: 36, height: 28)
                                .background(engine.shuffleMode == .on ? Color.red : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.cycleRepeatMode()
                        } label: {
                            Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(engine.repeatMode != .off ? .white : .secondary)
                                .frame(width: 36, height: 28)
                                .background(engine.repeatMode != .off ? Color.red : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.toggleAutoPlay()
                        } label: {
                            Image(systemName: "infinity")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(engine.isAutoPlayEnabled ? .white : .secondary)
                                .frame(width: 36, height: 28)
                                .background(engine.isAutoPlayEnabled ? Color.red : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button("Clear") {
                        engine.clearQueue()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
                
                Divider().opacity(0.3)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Now Playing
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Now playing")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            if let current = engine.currentTrack {
                                HStack(spacing: 12) {
                                    if let art = current.artworkURL {
                                        AsyncImage(url: art) { phase in
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
                                        Text(current.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(current.artist)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    
                                    Image(systemName: "waveform")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.trailing, 4)
                                    
                                    Button {
                                        engine.nextTrack()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                        
                        // MARK: - Next in queue
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Next in queue")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Clear") {
                                    engine.clearUpcomingQueue()
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            let upNext = engine.queue.enumerated().filter { $0.offset > engine.queueIndex }
                            if upNext.isEmpty {
                                Text("No upcoming tracks")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(upNext, id: \.element.id) { index, track in
                                        HStack(spacing: 12) {
                                            Image(systemName: "line.3.horizontal")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                            
                                            if let art = track.artworkURL {
                                                AsyncImage(url: art) { phase in
                                                    if let img = phase.image {
                                                        img.resizable().aspectRatio(contentMode: .fill)
                                                    } else {
                                                        Color.gray.opacity(0.3)
                                                    }
                                                }
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } else {
                                                BitChordLogoView(size: 40, cornerRadius: 6)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(track.artist)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            
                                            Button {
                                                engine.removeTrackFromQueue(at: index)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                                    .padding(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            engine.playTrack(at: index)
                                        }
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                                                selectedTrackForMenu = track
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        // MARK: - AutoPlay Section (Matching Car HU Photo 4)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "infinity")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(engine.isAutoPlayEnabled ? .red : .secondary)
                                Text("AutoPlay")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { engine.isAutoPlayEnabled },
                                    set: { _ in engine.toggleAutoPlay() }
                                ))
                                .labelsHidden()
                                .tint(.red)
                            }
                            .padding(.horizontal, 20)
                            
                            Text("Similar music, selected to play next")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 4) {
                                let displaySuggestions = dynamicAutoPlayTracks.isEmpty ? defaultFallbackSuggestions : dynamicAutoPlayTracks
                                ForEach(displaySuggestions) { track in
                                    HStack(spacing: 12) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        
                                        if let art = track.artworkURL {
                                            AsyncImage(url: art) { phase in
                                                if let img = phase.image {
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.gray.opacity(0.3)
                                                }
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        } else {
                                            BitChordLogoView(size: 40, cornerRadius: 6)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(track.artist)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        
                                        Button {
                                            engine.appendToQueue(track)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.primary)
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        engine.appendToQueue(track)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .onAppear {
                loadAutoPlayRecommendations()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheet(item: $selectedTrackForMenu) { track in
                TrackContextMenuSheet(track: track)
            }
        }
    }
}
