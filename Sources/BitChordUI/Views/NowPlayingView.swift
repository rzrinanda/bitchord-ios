import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLyrics: Bool = false
    @State private var showingQueue: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0
    
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
                        
                        // Audio Quality Badge
                        Text(track.audioBadge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundColor(.white.opacity(0.9))
                        
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
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 290, height: 290)
                                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 72))
                                .foregroundColor(.white.opacity(0.7))
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
                                
                                Text(track.artist)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                            
                            Button {} label: {
                                Image(systemName: "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
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
                            Text("-\(formatTime(max(0, engine.duration - (isDraggingSlider ? dragSliderValue : engine.currentTime))))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    
                    // Main Playback Controls
                    HStack(spacing: 40) {
                        Button {
                            engine.toggleShuffle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 20))
                                .foregroundColor(engine.shuffleMode == .on ? .red : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.togglePlayPause()
                        } label: {
                            Image(systemName: engine.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            engine.cycleRepeatMode()
                        } label: {
                            Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 20))
                                .foregroundColor(engine.repeatMode != .off ? .red : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)
                    
                    // Bottom Action Row
                    HStack(spacing: 48) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingLyrics.toggle()
                            }
                        } label: {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 20))
                                .foregroundColor(showingLyrics ? .white : .white.opacity(0.5))
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
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingQueue.toggle()
                        } label: {
                            Image(systemName: "list.dash")
                                .font(.system(size: 20))
                                .foregroundColor(showingQueue ? .white : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 34)
                }
            }
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheetView()
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
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Now Playing") {
                    if let track = engine.currentTrack {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text(track.title).font(.headline)
                                Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Up Next") {
                    ForEach(Array(engine.queue.enumerated()), id: \.offset) { index, track in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(track.title).font(.body)
                                Text(track.artist).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.playTrack(at: index)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            engine.removeTrackFromQueue(at: index)
                        }
                    }
                }
            }
            .navigationTitle("Playing Next")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
