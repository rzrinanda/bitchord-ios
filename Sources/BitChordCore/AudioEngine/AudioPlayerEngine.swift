import Foundation
import AVFoundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif

@MainActor
public final class AudioPlayerEngine: ObservableObject {
    public static let shared = AudioPlayerEngine()
    
    // Playback state
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var status: PlaybackStatus = .idle
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var playbackSpeed: Float = 1.0
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var bitPerfectEnabled: Bool = false
    @Published public var crossfadeDuration: TimeInterval = 3.0 // 0 to 12s
    @Published public var automixEnabled: Bool = false
    @Published public var skipSilenceEnabled: Bool = false
    
    // Queue & Modes
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public var repeatMode: RepeatMode = .off
    @Published public var shuffleMode: ShuffleMode = .off
    
    private var originalQueue: [Track] = []
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    public init() {
        setupAudioSession()
        setupRemoteCommands()
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
        queue.remove(at: index)
        if index < queueIndex {
            queueIndex -= 1
        }
    }
    
    public func toggleShuffle() {
        if shuffleMode == .off {
            shuffleMode = .on
            if let current = currentTrack {
                var remaining = queue.filter { $0.id != current.id }
                remaining.shuffle()
                queue = [current] + remaining
                queueIndex = 0
            }
        } else {
            shuffleMode = .off
            if let current = currentTrack, let originalIndex = originalQueue.firstIndex(where: { $0.id == current.id }) {
                queue = originalQueue
                queueIndex = originalIndex
            }
        }
    }
    
    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
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
        
        guard let url = track.streamURL else {
            // Placeholder: stream URL will be resolved asynchronously by stream extractor
            self.status = .playing
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        attachTimeObserver()
        player?.rate = playbackSpeed
        player?.play()
        self.status = .playing
        updateNowPlayingInfo()
    }
    
    public func togglePlayPause() {
        if status == .playing {
            pause()
        } else {
            resume()
        }
    }
    
    public func resume() {
        player?.rate = playbackSpeed
        player?.play()
        status = .playing
        updateNowPlayingInfo()
    }
    
    public func pause() {
        player?.pause()
        status = .paused
        updateNowPlayingInfo()
    }
    
    public func nextTrack() {
        if repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }
        
        if queueIndex + 1 < queue.count {
            playTrack(at: queueIndex + 1)
        } else if repeatMode == .all && !queue.isEmpty {
            playTrack(at: 0)
        } else {
            status = .idle
            currentTime = 0
        }
    }
    
    public func previousTrack() {
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        if queueIndex - 1 >= 0 {
            playTrack(at: queueIndex - 1)
        } else {
            seek(to: 0)
        }
    }
    
    public func seek(to time: TimeInterval) {
        currentTime = time
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
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
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds
                
                // Handle crossfade volume ramping
                if self.crossfadeDuration > 0 && self.duration > 0 {
                    let fadeVol = CrossfadeManager.shared.fadeOutVolume(
                        currentTime: self.currentTime,
                        duration: self.duration,
                        crossfadeDuration: self.crossfadeDuration
                    )
                    self.player?.volume = fadeVol * self.volume
                }
                
                // Auto transition at track completion
                if self.duration > 0 && self.currentTime >= (self.duration - 0.3) {
                    self.nextTrack()
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
        
        var info: [String: Any] = [
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
