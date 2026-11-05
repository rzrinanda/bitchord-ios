import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif

public struct NowPlayingView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var library = LibraryDatabase.shared
    @ObservedObject var settings = BitChordSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLyrics: Bool = false
    @State private var showingQueue: Bool = false
    @State private var showingAudioPipeline: Bool = false
    @State private var showingDownloadSheet: Bool = false
    @State private var showingLyricsSourceSheet: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0
    @State private var lastSeekTime: Date = Date.distantPast
    @State private var selectedTrackForMenu: Track? = nil
    @State private var currentLyricLine: String? = nil
    @State private var loadedLyrics: Lyrics? = nil
    @State private var currentActiveIndex: Int? = nil
    @State private var showBilingualTranslation: Bool = false
    @State private var currentDeviceRouteName: String = "Jack's Phone"
    
    public init() {}
    
    private var activeLyricSourceName: String {
        let sources = settings.getLyricSources()
        if let match = sources.first(where: { $0.id == settings.activeLyricSourceId }) {
            return match.name
        }
        return loadedLyrics?.provider ?? "BetterLyrics"
    }
    
    private func headerPlayingFromText(for track: Track) -> String {
        if library.isLiked(trackId: track.id) {
            return "Playing from Liked Songs"
        } else if !track.album.isEmpty && track.album != "YouTube Music" && track.album.lowercased() != track.title.lowercased() {
            return "Playing from \(track.album)"
        } else {
            return "Playing from Liked Songs"
        }
    }
    
    private func updateAudioRoute() {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        if let first = outputs.first {
            if first.portType == .builtInSpeaker || first.portType == .builtInReceiver {
                currentDeviceRouteName = UIDevice.current.name
                return
            }
            currentDeviceRouteName = first.portName
            return
        }
        currentDeviceRouteName = UIDevice.current.name
        #else
        currentDeviceRouteName = "Jack's Phone"
        #endif
    }
    
    public var body: some View {
        ZStack {
            DynamicBackgroundGradient(accentColor: .blue)
            
            if let track = engine.currentTrack {
                VStack(spacing: 0) {
                    // MARK: - Top Header (Image 1: Mini Header vs Image 2: Centered Title)
                    if showingLyrics {
                        // Image 1: Drag handle + Mini Track Header
                        VStack(spacing: 10) {
                            HStack {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 34, height: 34)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Capsule()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: 36, height: 4)
                                    .onTapGesture {
                                        dismiss()
                                    }
                                
                                Spacer()
                                
                                Color.clear.frame(width: 34, height: 34)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            
                            HStack(spacing: 12) {
                                TrackArtworkView(track: track, size: 44, cornerRadius: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(track.artist)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.65))
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Heart / Like button in subtle circular button
                                Button {
                                    library.toggleLike(track: track)
                                } label: {
                                    Image(systemName: library.isLiked(trackId: track.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(library.isLiked(trackId: track.id) ? .red : .white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                // More '...' button in subtle circular button
                                Button {
                                    selectedTrackForMenu = track
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.height > 45 {
                                        dismiss()
                                    }
                                }
                        )
                    } else {
                        // Image 2: Drag handle + Dismiss button + Centered "Playing from Liked Songs"
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            VStack(spacing: 6) {
                                Capsule()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: 36, height: 4)
                                
                                if !settings.hideSongStatus {
                                    Text(engine.status == .loading ? "Memuat audio..." : headerPlayingFromText(for: track))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(engine.status == .loading ? .cyan : .white.opacity(0.75))
                                        .padding(.top, 2)
                                }
                            }
                            .onTapGesture {
                                dismiss()
                            }
                            
                            Spacer()
                            
                            Color.clear.frame(width: 34, height: 34)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.height > 45 {
                                        dismiss()
                                    }
                                }
                        )
                    }
                    
                    // MARK: - Stats for Nerds Live Telemetry Overlay
                    if settings.statsForNerdsEnabled {
                        Button {
                            showingAudioPipeline = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label("STATS FOR NERDS", systemImage: "cpu")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                    Spacer()
                                    Text(engine.activeBackend == .avPlayer ? "DIRECT STREAM" : "YT ENGINE")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.2))
                                        .foregroundColor(.cyan)
                                        .clipShape(Capsule())
                                }
                                
                                let codecText = track.isLossless ? "FLAC / ALAC" : "AAC-LC / Opus"
                                let srKhz = String(format: "%.1f kHz", (track.sampleRate ?? 44100) / 1000.0)
                                let bitDepthText = track.isLossless ? "\(track.bitDepth ?? ((track.sampleRate ?? 44100) > 48000 ? 24 : 16))-bit" : "16-bit"
                                let bitrateText = track.isLossless ? ((track.sampleRate ?? 44100) > 48000 ? "4608 kbps" : "1411 kbps") : "256 kbps"
                                
                                Text("Codec: \(codecText) • \(bitDepthText) / \(srKhz) • \(bitrateText)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.92))
                                    .lineLimit(1)
                                
                                Text("Pipeline: CoreAudio \(settings.outputPrecision) • Route: \(currentDeviceRouteName) • ID: \(track.id)")
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Center Content (Image 1: Synced Lyrics vs Image 2: Large Artwork)
                    if showingLyrics {
                        // Full Synced Lyrics Scroll Area (Image 1)
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 22) {
                                    if let lyrics = loadedLyrics, !lyrics.lines.isEmpty {
                                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                            let isActive = currentActiveIndex == index
                                            
                                            Button {
                                                engine.seek(to: line.timestamp)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(line.text)
                                                        .font(.system(size: isActive ? 28 : 22, weight: isActive ? .bold : .bold, design: .rounded))
                                                        .foregroundColor(isActive ? .white : .white.opacity(settings.blurUnfocusedLyrics ? 0.35 : 0.5))
                                                        .blur(radius: (isActive || !settings.blurUnfocusedLyrics) ? 0 : 0.6)
                                                        .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                                        .multilineTextAlignment(.leading)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                    
                                                    if showBilingualTranslation, let trans = line.translation, !trans.isEmpty {
                                                        Text(trans)
                                                            .font(.system(size: isActive ? 16 : 14, weight: .medium, design: .rounded))
                                                            .foregroundColor(isActive ? .white.opacity(0.85) : .white.opacity(0.3))
                                                    }
                                                }
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .id(index)
                                        }
                                    } else if let plain = loadedLyrics?.plainLyrics, !plain.isEmpty {
                                        Text(plain)
                                            .font(.system(size: 20, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.85))
                                            .lineSpacing(10)
                                            .padding(.vertical, 20)
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 32))
                                                .foregroundColor(.white.opacity(0.4))
                                            Text("No lyrics available")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 80)
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.top, 14)
                                .padding(.bottom, 20)
                            }
                            .onChange(of: currentActiveIndex) { _, newIndex in
                                if let active = newIndex {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        proxy.scrollTo(active, anchor: .center)
                                    }
                                }
                            }
                        }
                        
                        // Lyrics Footer: [Globe] [Lyrics by BetterLyrics Change] [Translation]
                        VStack(spacing: 8) {
                            HStack {
                                Button {
                                    // Romanization / pronunciation action
                                } label: {
                                    Image(systemName: "globe")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation {
                                        showBilingualTranslation.toggle()
                                        settings.showBilingualLyrics = showBilingualTranslation
                                    }
                                } label: {
                                    Image(systemName: "translate")
                                        .font(.system(size: 15))
                                        .foregroundColor(showBilingualTranslation ? .white : .white.opacity(0.85))
                                        .frame(width: 36, height: 36)
                                        .background(showBilingualTranslation ? Color.teal.opacity(0.6) : Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 28)
                            
                            HStack(spacing: 6) {
                                Text("Lyrics by \(activeLyricSourceName)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.65))
                                
                                Button {
                                    showingLyricsSourceSheet = true
                                } label: {
                                    Text("Change")
                                        .font(.system(size: 13, weight: .semibold))
                                        .underline()
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 6)
                        }
                    } else {
                        // Large Artwork & Track Details (Image 2)
                        Spacer(minLength: 6)
                        
                        ZStack {
                            TrackArtworkView(track: track, size: 290, cornerRadius: 22)
                                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                        }
                        .scaleEffect(engine.status == .playing ? 1.0 : 0.92)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.status)
                        
                        Spacer(minLength: 10)
                        
                        // Track Info Row: Title + Artist, Star, More
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    library.toggleLike(track: track)
                                } label: {
                                    Image(systemName: library.isLiked(trackId: track.id) ? "star.fill" : "star")
                                        .font(.system(size: 18))
                                        .foregroundColor(library.isLiked(trackId: track.id) ? .yellow : .white)
                                        .frame(width: 38, height: 38)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    selectedTrackForMenu = track
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 28)
                        
                        // Single-Line Lyric Snippet with '>' (Tapping flips to Full Lyrics!)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingLyrics = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let line = currentLyricLine, !line.isEmpty {
                                    Text(line)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.95))
                                        .lineLimit(1)
                                } else {
                                    Text("Instrumental")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Scrubber Bar
                    VStack(spacing: 6) {
                        let displayTime: Double = {
                            if isDraggingSlider {
                                return dragSliderValue
                            } else if Date().timeIntervalSince(lastSeekTime) < 0.35 {
                                return dragSliderValue
                            } else {
                                return engine.currentTime
                            }
                        }()
                        
                        Slider(
                            value: Binding(
                                get: { displayTime },
                                set: { newValue in
                                    dragSliderValue = newValue
                                }
                            ),
                            in: 0...max(1, engine.duration),
                            onEditingChanged: { editing in
                                if editing {
                                    isDraggingSlider = true
                                    dragSliderValue = displayTime
                                } else {
                                    let seekTarget = dragSliderValue
                                    lastSeekTime = Date()
                                    engine.seek(to: seekTarget)
                                    isDraggingSlider = false
                                }
                            }
                        )
                        .tint(.white)
                        
                        HStack {
                            Text(formatTime(displayTime))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            if !showingLyrics {
                                // Audio Quality Trigger Pill (Image 2)
                                Button {
                                    showingAudioPipeline = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 11))
                                        Text(track.displayAudioQualityBadge)
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
                            }
                            
                            Text("-\(formatTime(max(0, engine.duration - displayTime)))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                    
                    // MARK: - Main Playback Controls
                    HStack(spacing: 48) {
                        Button {
                            engine.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.togglePlayPause()
                        } label: {
                            if engine.status == .loading {
                                ProgressView()
                                    .scaleEffect(1.4)
                                    .tint(.white)
                                    .frame(width: 48, height: 48)
                            } else {
                                Image(systemName: engine.status == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 46))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 14)
                    
                    // MARK: - Volume Slider
                    if !settings.hideVolumeSlider {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Slider(
                                value: Binding(
                                    get: { Double(engine.volume) },
                                    set: { engine.setVolume(Float($0)) }
                                ),
                                in: 0...1
                            )
                            .tint(.white)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 14)
                    }
                    
                    // MARK: - Bottom Action Row
                    HStack {
                        // Lyric Toggle Button
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingLyrics.toggle()
                            }
                        } label: {
                            Image(systemName: showingLyrics ? "quote.bubble.fill" : "quote.bubble")
                                .font(.system(size: 19))
                                .foregroundColor(showingLyrics ? .white : .white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(showingLyrics ? Color.white.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if showingLyrics && settings.showListenTogetherButton {
                            // Joined Headphones + Person capsule as seen in Reference Image 1
                            HStack(spacing: 0) {
                                Button {
                                    // Route picker
                                } label: {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 17))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 44, height: 38)
                                }
                                .buttonStyle(.plain)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 1, height: 20)
                                
                                Button {
                                    // Profile / Listen together
                                } label: {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 44, height: 38)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        } else {
                            // Standalone Headphones / Audio Output Route as seen in Reference Image 2
                            Button {
                                // Route picker
                            } label: {
                                Image(systemName: "headphones")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        // Queue Button
                        Button {
                            showingQueue.toggle()
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 4)
                    
                    // Device Name Label at Bottom
                    Text(currentDeviceRouteName)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheetView()
        }
        .sheet(isPresented: $showingDownloadSheet) {
            if let track = engine.currentTrack {
                DownloadSheetView(track: track)
            }
        }
        .sheet(item: $selectedTrackForMenu) { track in
            TrackContextMenuSheet(track: track)
        }
        .sheet(isPresented: $showingAudioPipeline) {
            if let track = engine.currentTrack {
                AudioPipelineSheet(track: track)
            }
        }
        .sheet(isPresented: $showingLyricsSourceSheet) {
            if let track = engine.currentTrack {
                LyricsSourcePickerSheet(track: track) { chosenSource in
                    Task {
                        let l = await LyricsManager.shared.loadLyrics(for: track, provider: chosenSource.name)
                        self.loadedLyrics = l
                        self.currentActiveIndex = l?.activeLineIndex(for: engine.currentTime)
                    }
                }
            }
        }
        .task(id: engine.currentTrack?.id) {
            guard let track = engine.currentTrack else {
                currentLyricLine = nil
                loadedLyrics = nil
                currentActiveIndex = nil
                return
            }
            let l = await LyricsManager.shared.loadLyrics(for: track, provider: activeLyricSourceName)
            self.loadedLyrics = l
            if let l = l {
                let idx = l.activeLineIndex(for: engine.currentTime)
                self.currentActiveIndex = idx
                if let idx = idx, idx < l.lines.count {
                    currentLyricLine = l.lines[idx].text
                } else {
                    currentLyricLine = l.lines.first?.text
                }
            } else {
                currentLyricLine = nil
                currentActiveIndex = nil
            }
        }
        .onChange(of: engine.currentTime) { _, newTime in
            if let l = loadedLyrics {
                let idx = l.activeLineIndex(for: newTime)
                if idx != currentActiveIndex {
                    currentActiveIndex = idx
                    if let idx = idx, idx < l.lines.count {
                        currentLyricLine = l.lines[idx].text
                    }
                }
            }
        }
        .onChange(of: engine.currentTrack?.id) { _, _ in
            isDraggingSlider = false
            dragSliderValue = 0
            lastSeekTime = Date.distantPast
        }
        .onAppear {
            if settings.showFullLyrics {
                showingLyrics = true
            }
            if settings.showBilingualLyrics {
                showBilingualTranslation = true
            }
            updateAudioRoute()
        }
        .onChange(of: settings.showFullLyrics) { _, newValue in
            showingLyrics = newValue
        }
        #if os(iOS)
        .statusBarHidden(settings.hideStatusBarInPlayer)
        #endif
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Lyrics Source Picker Sheet (Triggered by 'Change' in Image 1)
public struct LyricsSourcePickerSheet: View {
    @ObservedObject var settings = BitChordSettings.shared
    public let track: Track
    public let onSelect: (LyricSourceItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(track: Track, onSelect: @escaping (LyricSourceItem) -> Void) {
        self.track = track
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(settings.getLyricSources()) { source in
                        Button {
                            settings.activeLyricSourceId = source.id
                            onSelect(source)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(source.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if settings.activeLyricSourceId == source.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.teal)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("LYRIC SOURCES")
                }
            }
            .navigationTitle("Select Lyrics Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

public struct QueueSheetView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var settings = BitChordSettings.shared
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
                        // MARK: - Queue History (When Show Queue History is enabled)
                        if settings.showQueueHistory && engine.queueIndex > 0 {
                            let historyItems = Array(engine.queue.enumerated().prefix(engine.queueIndex).suffix(25))
                            if !historyItems.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Previously played")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                    
                                    VStack(spacing: 4) {
                                        ForEach(historyItems, id: \.element.id) { index, track in
                                            HStack(spacing: 12) {
                                                TrackArtworkView(track: track, size: 38, cornerRadius: 6)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(track.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                    Text(track.artist)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary.opacity(0.8))
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 4)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                engine.playTrack(at: index)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        // MARK: - Now Playing
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Now playing")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            if let current = engine.currentTrack {
                                HStack(spacing: 12) {
                                    TrackArtworkView(track: current, size: 44, cornerRadius: 8)
                                    
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
                                            
                                            TrackArtworkView(track: track, size: 40, cornerRadius: 6)
                                            
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
                                        
                                        TrackArtworkView(track: track, size: 40, cornerRadius: 6)
                                        
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
