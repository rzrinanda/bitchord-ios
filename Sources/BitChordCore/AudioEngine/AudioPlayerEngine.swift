import Foundation
import AVFoundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif

public enum PlaybackBackend: String, Sendable {
    case none
    case youtubeBridge
    case avPlayer
}

@MainActor
public final class AudioPlayerEngine: ObservableObject {
    public static let shared = AudioPlayerEngine()
    
    // Playback state
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var status: PlaybackStatus = .idle
    @Published public private(set) var activeBackend: PlaybackBackend = .none
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var playbackSpeed: Float = 1.0
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var bitPerfectEnabled: Bool = false
    @Published public var crossfadeDuration: TimeInterval = 3.0 // 0 to 12s
    @Published public var automixEnabled: Bool = false
    @Published public var isAutoPlayEnabled: Bool = true
    @Published public var skipSilenceEnabled: Bool = false
    
    // Queue & Modes
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public var repeatMode: RepeatMode = .off
    @Published public var shuffleMode: ShuffleMode = .off
    
    private var originalQueue: [Track] = []
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var playerItemObservation: NSKeyValueObservation?
    private var playerItemEndObserver: NSObjectProtocol?
    
    public init() {
        setupAudioSession()
        setupRemoteCommands()
        setupYouTubeBridge()
    }
    
    private func setupYouTubeBridge() {
        YouTubeAudioBridge.shared.onPlaybackEnded = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleTrackFinished()
            }
        }
        YouTubeAudioBridge.shared.onPlaybackStateChanged = { [weak self] newStatus in
            Task { @MainActor [weak self] in
                self?.status = newStatus
                self?.updateNowPlayingInfo()
            }
        }
        YouTubeAudioBridge.shared.onTimeUpdated = { [weak self] cur, dur in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = cur
                if dur > 0 && abs(self.duration - dur) > 1.0 {
                    self.duration = dur
                }
            }
        }
        YouTubeAudioBridge.shared.onPlaybackError = { [weak self] code in
            Task { @MainActor [weak self] in
                guard let self = self, let track = self.currentTrack else { return }
                print("[AudioEngine] YouTube Audio Bridge error (\(code)) - fallback to direct audio stream")
                self.attemptStreamFallback(for: track)
            }
        }
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("[BitChord AudioEngine] Failed to activate AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Queue Management
    
    public func setQueue(_ tracks: [Track], startIndex: Int = 0) {
        guard !tracks.isEmpty else { return }
        self.originalQueue = tracks
        self.queue = tracks
        self.queueIndex = min(max(0, startIndex), tracks.count - 1)
        
        // If shuffle is active when setting a new queue, preserve active song and shuffle upcoming
        if shuffleMode == .on {
            let active = tracks[self.queueIndex]
            var others = tracks.filter { $0.id != active.id }
            others.shuffle()
            self.queue = [active] + others
            self.queueIndex = 0
        }
        
        playTrack(at: self.queueIndex)
    }
    
    public func appendToQueue(_ track: Track) {
        queue.append(track)
        originalQueue.append(track)
    }
    
    public func insertNextInQueue(_ track: Track) {
        let insertIndex = min(queueIndex + 1, queue.count)
        queue.insert(track, at: insertIndex)
        originalQueue.insert(track, at: insertIndex)
    }
    
    public func removeTrackFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let removed = queue.remove(at: index)
        if let origIdx = originalQueue.firstIndex(where: { $0.id == removed.id }) {
            originalQueue.remove(at: origIdx)
        }
        if index < queueIndex {
            queueIndex -= 1
        }
    }
    
    public func clearUpcomingQueue() {
        guard queueIndex < queue.count else { return }
        let kept = Array(queue.prefix(queueIndex + 1))
        queue = kept
        originalQueue = originalQueue.filter { orig in
            kept.contains(where: { $0.id == orig.id })
        }
    }
    
    public func clearQueue() {
        if let current = currentTrack {
            queue = [current]
            originalQueue = [current]
            queueIndex = 0
        }
    }
    
    public func toggleShuffle() {
        if shuffleMode == .off {
            shuffleMode = .on
            guard !queue.isEmpty else { return }
            
            // Snapshot canonical queue
            if originalQueue.isEmpty || originalQueue.count != queue.count {
                originalQueue = queue
            }
            
            // Keep past history and currently playing track intact, shuffle only unconsumed upcoming tracks
            let history = Array(queue.prefix(queueIndex))
            let current = queue[queueIndex]
            var upcoming = Array(queue.suffix(from: min(queueIndex + 1, queue.count)))
            upcoming.shuffle()
            
            self.queue = history + [current] + upcoming
            self.queueIndex = history.count
        } else {
            shuffleMode = .off
            guard !originalQueue.isEmpty else { return }
            
            // Restore original canonical order around current track
            if let current = currentTrack, let originalIndex = originalQueue.firstIndex(where: { $0.id == current.id }) {
                self.queue = originalQueue
                self.queueIndex = originalIndex
            } else {
                self.queue = originalQueue
                self.queueIndex = min(self.queueIndex, max(0, self.queue.count - 1))
            }
        }
    }
    
    public func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    public func toggleAutoPlay() {
        isAutoPlayEnabled.toggle()
    }
    
    // MARK: - Playback Control
    
    public func playTrack(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queueIndex = index
        let track = queue[index]
        self.currentTrack = track
        self.duration = track.duration
        self.currentTime = 0
        self.status = .loading
        
        // 1. If direct offline or file URL is present, use AVPlayer
        if let directURL = track.streamURL, directURL.isFileURL {
            YouTubeAudioBridge.shared.pause()
            startPlaying(url: directURL, for: track)
            return
        }
        
        // 2. If track already has a valid 11-char YouTube ID, play via YouTubeAudioBridge with auto-fallback
        if track.id.count == 11 && !track.id.hasPrefix("yt_") {
            self.stopAVPlayer()
            self.activeBackend = .youtubeBridge
            YouTubeAudioBridge.shared.play(videoId: track.id)
            self.status = .loading
            self.updateNowPlayingInfo()
            
            // Watchdog fallback: if YouTubeAudioBridge doesn't start producing time/audio within 6.0s, fall back to AVPlayer!
            let targetTrackId = track.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self = self, self.currentTrack?.id == targetTrackId else { return }
                if self.status != .playing || self.currentTime == 0 {
                    print("[AudioEngine] YouTube Audio Bridge startup timed out for \(targetTrackId), switching to AVPlayer stream fallback")
                    self.attemptStreamFallback(for: track)
                }
            }
            return
        }
        
        // 3. Resolve real 11-char YouTube videoId for titles / search metadata
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let vId = await YTMusicClient.shared.resolveYouTubeVideoId(title: track.title, artist: track.artist) {
                var updated = track
                updated.id = vId
                if self.queueIndex == index {
                    self.currentTrack = updated
                    if index < self.queue.count {
                        self.queue[index] = updated
                    }
                    self.stopAVPlayer()
                    self.activeBackend = .youtubeBridge
                    YouTubeAudioBridge.shared.play(videoId: vId)
                    self.status = .playing
                    self.updateNowPlayingInfo()
                }
            } else if let directURL = track.streamURL, !directURL.absoluteString.contains("apple.com") {
                self.startPlaying(url: directURL, for: track)
            } else {
                self.attemptStreamFallback(for: track)
            }
        }
    }
    
    private func startPlaying(url: URL, for track: Track) {
        self.activeBackend = .avPlayer
        YouTubeAudioBridge.shared.pause()
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        
        if let observer = playerItemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemEndObserver = nil
        }
        
        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Observe buffer and playback readiness
        playerItemObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.status = .playing
                    self.player?.rate = self.playbackSpeed
                    self.player?.play()
                    self.updateNowPlayingInfo()
                case .failed:
                    print("[BitChord AudioEngine] AVPlayerItem failed: \(String(describing: item.error))")
                    self.attemptStreamFallback(for: track)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTrackFinished()
            }
        }
        
        attachTimeObserver()
        player?.rate = playbackSpeed
        player?.play()
        self.status = .playing
        updateNowPlayingInfo()
    }
    
    private func handleTrackFinished() {
        switch repeatMode {
        case .one:
            // Loop current track seamlessly across active backends
            switch activeBackend {
            case .youtubeBridge:
                YouTubeAudioBridge.shared.seek(to: 0)
                YouTubeAudioBridge.shared.resume()
                self.currentTime = 0
                self.status = .playing
                self.updateNowPlayingInfo()
            case .avPlayer:
                player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.currentTime = 0
                        self?.player?.play()
                        self?.status = .playing
                        self?.updateNowPlayingInfo()
                    }
                }
            case .none:
                break
            }
        case .all:
            // Loop entire queue seamlessly
            if queueIndex + 1 < queue.count {
                playTrack(at: queueIndex + 1)
            } else if !queue.isEmpty {
                playTrack(at: 0)
            }
        case .off:
            if queueIndex + 1 < queue.count {
                playTrack(at: queueIndex + 1)
            } else if isAutoPlayEnabled, let current = currentTrack {
                fetchAndPlayAutoPlay(for: current)
            } else {
                status = .paused
                currentTime = 0
                updateNowPlayingInfo()
            }
        }
    }
    
    private func fetchAndPlayAutoPlay(for current: Track) {
        guard isAutoPlayEnabled else {
            status = .paused
            currentTime = 0
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let more = await YTMusicClient.shared.fetchRadioTracks(for: current)
            if !more.isEmpty {
                let nextIdx = self.queue.count
                for t in more {
                    if !self.queue.contains(where: { $0.id == t.id }) {
                        self.queue.append(t)
                        self.originalQueue.append(t)
                    }
                }
                if nextIdx < self.queue.count {
                    self.playTrack(at: nextIdx)
                } else {
                    self.status = .paused
                    self.currentTime = 0
                }
            } else {
                self.status = .paused
                self.currentTime = 0
            }
        }
    }
    
    private func attemptStreamFallback(for track: Track) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.currentTrack?.id == track.id else { return }
            
            // 1. Direct streamURL on track if already present (excluding snippet previews)
            if let streamURL = track.streamURL, !streamURL.absoluteString.contains("apple.com") {
                print("[BitChord AudioEngine] Using track's existing full streamURL: \(streamURL)")
                self.startPlaying(url: streamURL, for: track)
                return
            }
            
            // 2. High-Fidelity Multi-source StreamExtractor (Full Length Audio Only)
            if let streamInfo = try? await StreamExtractor.shared.extractAudioStream(trackId: track.id, title: track.title, artist: track.artist) {
                print("[BitChord AudioEngine] StreamExtractor recovered full stream: \(streamInfo.streamURL)")
                var recoveredTrack = track
                recoveredTrack.streamURL = streamInfo.streamURL
                self.currentTrack = recoveredTrack
                if self.queueIndex < self.queue.count {
                    self.queue[self.queueIndex] = recoveredTrack
                }
                self.startPlaying(url: streamInfo.streamURL, for: recoveredTrack)
                return
            }
            
            self.status = .error
        }
    }
    
    public func togglePlayPause() {
        if status == .playing {
            pause()
        } else {
            resume()
        }
    }
    
    public func resume() {
        switch activeBackend {
        case .youtubeBridge:
            YouTubeAudioBridge.shared.resume()
        case .avPlayer:
            player?.rate = playbackSpeed
            player?.play()
        case .none:
            if !queue.isEmpty {
                playTrack(at: queueIndex)
            }
        }
        status = .playing
        updateNowPlayingInfo()
    }
    
    public func pause() {
        YouTubeAudioBridge.shared.pause()
        player?.pause()
        status = .paused
        updateNowPlayingInfo()
    }
    
    public func stop() {
        YouTubeAudioBridge.shared.pause()
        stopAVPlayer()
        activeBackend = .none
        status = .idle
        currentTime = 0
        updateNowPlayingInfo()
    }
    
    public func stopAVPlayer() {
        if let observer = playerItemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemEndObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
    
    public func nextTrack() {
        if repeatMode == .one {
            // Manual Next skips ahead even if repeat one is on
            if queueIndex + 1 < queue.count {
                playTrack(at: queueIndex + 1)
            } else if !queue.isEmpty {
                playTrack(at: 0)
            }
            return
        }
        
        if queueIndex + 1 < queue.count {
            playTrack(at: queueIndex + 1)
        } else if repeatMode == .all && !queue.isEmpty {
            playTrack(at: 0)
        } else if isAutoPlayEnabled, let current = currentTrack {
            fetchAndPlayAutoPlay(for: current)
        } else {
            status = .paused
            currentTime = 0
            updateNowPlayingInfo()
        }
    }
    
    public func previousTrack() {
        if currentTime > 3.0 {
            seek(to: 0)
            resume()
            return
        }
        
        if queueIndex - 1 >= 0 {
            playTrack(at: queueIndex - 1)
        } else if repeatMode == .all && queue.count > 1 {
            playTrack(at: queue.count - 1)
        } else {
            seek(to: 0)
            resume()
        }
    }
    
    public func startRadio(for track: Track) {
        setQueue([track], startIndex: 0)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let radioTracks = await YTMusicClient.shared.fetchRadioTracks(for: track)
            for t in radioTracks {
                if !self.queue.contains(where: { $0.id == t.id }) {
                    self.queue.append(t)
                    self.originalQueue.append(t)
                }
            }
        }
    }
    
    public func seek(to time: TimeInterval) {
        currentTime = time
        switch activeBackend {
        case .youtubeBridge:
            YouTubeAudioBridge.shared.seek(to: time)
        case .avPlayer:
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        case .none:
            break
        }
        updateNowPlayingInfo()
    }
    
    public func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if status == .playing {
            player?.rate = speed
        }
    }
    
    // MARK: - Observers & Now Playing
    
    private func attachTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds
                
                // Keep actual audio stream duration synchronized
                if let item = self.player?.currentItem {
                    let realDuration = item.duration.seconds
                    if realDuration.isFinite && realDuration > 0 && abs(self.duration - realDuration) > 0.5 {
                        self.duration = realDuration
                    }
                }
                
                // Handle crossfade volume ramping
                if self.crossfadeDuration > 0 && self.duration > 0 {
                    let fadeVol = CrossfadeManager.shared.fadeOutVolume(
                        currentTime: self.currentTime,
                        duration: self.duration,
                        crossfadeDuration: self.crossfadeDuration
                    )
                    self.player?.volume = fadeVol * self.volume
                }
            }
        }
    }
    
    private func setupRemoteCommands() {
        #if canImport(MediaPlayer)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
        #endif
    }
    
    private func updateNowPlayingInfo() {
        #if canImport(MediaPlayer)
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? playbackSpeed : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }
}
