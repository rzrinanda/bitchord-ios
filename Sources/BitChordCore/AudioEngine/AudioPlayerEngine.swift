import Foundation
import AVFoundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if canImport(UIKit)
import UIKit
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
    private var pendingSeekTime: TimeInterval? = nil
    private var lastSavedProgressTimestamp: TimeInterval = 0
    
    #if os(iOS)
    private var silencePlayer: AVAudioPlayer?
    private var cachedArtworkImage: UIImage?
    private var cachedTrackId: String?
    #endif
    
    public init() {
        setupAudioSession()
        setupRemoteCommands()
        setupYouTubeBridge()
        restoreLastPlayedSession()
    }
    
    private func restoreLastPlayedSession() {
        let db = LibraryDatabase.shared
        guard self.currentTrack == nil, let lastTrack = db.recentTracks.first else { return }
        self.queue = db.recentTracks
        self.originalQueue = db.recentTracks
        self.queueIndex = 0
        self.currentTrack = lastTrack
        let savedDur = db.lastPlaybackDuration > 0 ? db.lastPlaybackDuration : lastTrack.duration
        self.duration = savedDur
        let savedPos = min(max(0, db.lastPlaybackPosition), max(0, savedDur - 5))
        self.currentTime = savedPos
        self.pendingSeekTime = savedPos > 2 ? savedPos : nil
        self.status = .paused
        self.updateNowPlayingInfo()
    }
    
    private func setupYouTubeBridge() {
        YouTubeAudioBridge.shared.onPlaybackEnded = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.activeBackend == .youtubeBridge else { return }
                self.handleTrackFinished()
            }
        }
        YouTubeAudioBridge.shared.onPlaybackStateChanged = { [weak self] newStatus in
            Task { @MainActor [weak self] in
                guard let self = self, self.activeBackend == .youtubeBridge else { return }
                self.status = newStatus
                self.updateNowPlayingInfo()
            }
        }
        YouTubeAudioBridge.shared.onTimeUpdated = { [weak self] cur, dur in
            Task { @MainActor [weak self] in
                guard let self = self, self.activeBackend == .youtubeBridge else { return }
                // Guard against short clips/teasers (< 55s) when track is a full song
                if dur > 0 && dur < 55, let track = self.currentTrack, track.duration >= 60 {
                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(title: track.title, artist: track.artist), topicId != track.id {
                        var updated = track
                        updated.id = topicId
                        self.currentTrack = updated
                        if self.queueIndex < self.queue.count {
                            self.queue[self.queueIndex] = updated
                        }
                        YouTubeAudioBridge.shared.play(videoId: topicId)
                        return
                    }
                }
                self.currentTime = cur
                if dur >= 55 && abs(self.duration - dur) > 1.0 {
                    self.duration = dur
                }
                if let seekTarget = self.pendingSeekTime, seekTarget > 2, cur < 2.0, dur > seekTarget {
                    self.pendingSeekTime = nil
                    YouTubeAudioBridge.shared.seek(to: seekTarget)
                    self.currentTime = seekTarget
                }
                if abs(cur - self.lastSavedProgressTimestamp) >= 2.0 {
                    self.lastSavedProgressTimestamp = cur
                    LibraryDatabase.shared.updateLastPlaybackProgress(position: cur, duration: self.duration)
                }
            }
        }
        YouTubeAudioBridge.shared.onPlaybackError = { [weak self] code in
            Task { @MainActor [weak self] in
                guard let self = self, let track = self.currentTrack else { return }
                print("[AudioEngine] YouTube Audio Bridge error (\(code)) - resolving topic or fallback stream")
                
                // If embedding is restricted (101, 150, 152), automatically try the official Topic track
                if code == 101 || code == 150 || code == 152 {
                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(title: track.title, artist: track.artist), topicId != track.id {
                        print("[AudioEngine] Switching to Topic videoId: \(topicId)")
                        var updated = track
                        updated.id = topicId
                        self.currentTrack = updated
                        if self.queueIndex < self.queue.count {
                            self.queue[self.queueIndex] = updated
                        }
                        YouTubeAudioBridge.shared.play(videoId: topicId)
                        return
                    }
                }
                
                self.attemptStreamFallback(for: track)
            }
        }
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[BitChord AudioEngine] Failed to activate AVAudioSession: \(error.localizedDescription)")
        }
        
        // Listen to interruption notifications (phone calls, Siri, alarms)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let userInfo = notif.userInfo,
                      let typeVal = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
                
                if type == .began {
                    self.pause()
                } else if type == .ended {
                    if let optVal = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optVal).contains(.shouldResume) {
                        self.resume()
                    }
                }
            }
        }
        
        // Listen to route change notifications (unplugging headphones, Bluetooth disconnect)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let userInfo = notif.userInfo,
                      let reasonVal = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal) else { return }
                
                if reason == .oldDeviceUnavailable {
                    self.pause()
                } else if BitChordSettings.shared.disableOnPhoneSpeaker {
                    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
                    if !outputs.isEmpty && outputs.allSatisfy({ $0.portType == .builtInSpeaker || $0.portType == .builtInReceiver }) {
                        if reason != .categoryChange && self.status == .playing {
                            self.pause()
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.beginBackgroundTask()
                self.startKeepAlive()
                if self.status == .playing {
                    if self.activeBackend == .youtubeBridge, let track = self.currentTrack, let streamURL = track.streamURL {
                        let currentPos = self.currentTime
                        self.startPlaying(url: streamURL, for: track, initialSeek: currentPos)
                    } else if self.activeBackend == .youtubeBridge {
                        YouTubeAudioBridge.shared.resume()
                    }
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.endBackgroundTask()
                if self.status == .playing {
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.status == .playing {
                    self.beginBackgroundTask()
                    self.startKeepAlive()
                    YouTubeAudioBridge.shared.resume()
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.status == .playing {
                    self.updateNowPlayingInfo()
                }
            }
        }
        #endif
    }
    
    #if os(iOS)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    public func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "BitChordPlaybackKeepAlive") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
    }
    
    public func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    
    private func setupKeepAlive() {
        guard silencePlayer == nil else { return }
        let url = makeSilentWAV()
        if let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1
            player.volume = 0.05 // Active hardware frame energy keeps mediaserverd alive
            player.prepareToPlay()
            self.silencePlayer = player
        }
    }
    
    public func startKeepAlive() {
        setupKeepAlive()
        if silencePlayer?.isPlaying != true {
            silencePlayer?.play()
        }
    }
    
    public func pauseKeepAlive() {
        silencePlayer?.pause()
    }
    
    private func makeSilentWAV() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("bitchord_keepalive.wav")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        let sampleRate: Int32 = 44100
        let numChannels: Int16 = 2
        let bitsPerSample: Int16 = 16
        let durationSeconds: Int32 = 1
        let numSamples: Int32 = sampleRate * durationSeconds
        let subChunk2Size: Int32 = numSamples * Int32(numChannels) * Int32(bitsPerSample / 8)
        let chunkSize: Int32 = 36 + subChunk2Size
        let byteRate: Int32 = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign: Int16 = numChannels * (bitsPerSample / 8)
        
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        let subChunk1Size: Int32 = 16
        let audioFormat: Int16 = 1
        data.append(contentsOf: withUnsafeBytes(of: subChunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: subChunk2Size.littleEndian) { Array($0) })
        
        // Generate inaudible 1-bit dither (±2 amplitude in 16-bit range) so mediaserverd never marks session as zero-energy
        var pcm = Data(capacity: Int(subChunk2Size))
        for i in 0..<numSamples {
            let sampleVal: Int16 = (i % 2 == 0) ? 2 : -2
            withUnsafeBytes(of: sampleVal.littleEndian) { bytes in
                pcm.append(contentsOf: bytes)
                pcm.append(contentsOf: bytes)
            }
        }
        data.append(pcm)
        
        try? data.write(to: fileURL)
        return fileURL
    }
    #endif
    
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
    
    public func playTrack(at index: Int, initialSeek: TimeInterval? = nil) {
        guard index >= 0 && index < queue.count else { return }
        queueIndex = index
        let track = queue[index]
        self.currentTrack = track
        self.duration = track.duration
        let startPos = initialSeek ?? 0
        self.currentTime = startPos
        self.pendingSeekTime = startPos > 2 ? startPos : nil
        self.status = .loading
        LibraryDatabase.shared.recordPlayback(track: track)
        if startPos > 0 {
            LibraryDatabase.shared.updateLastPlaybackProgress(position: startPos, duration: track.duration)
        }
        
        #if os(iOS)
        startKeepAlive()
        #endif
        
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
            
            // Concurrently extract native direct stream for AVPlayer (enabling uninterrupted lock-screen audio)
            let targetTrackId = track.id
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let streamInfo = try? await StreamExtractor.shared.extractAudioStream(trackId: targetTrackId, title: track.title, artist: track.artist) {
                    guard self.currentTrack?.id == targetTrackId else { return }
                    var updated = track
                    updated.streamURL = streamInfo.streamURL
                    updated.isLossless = streamInfo.isLossless
                    updated.sampleRate = streamInfo.sampleRate
                    updated.bitDepth = streamInfo.bitDepth
                    self.currentTrack = updated
                    if self.queueIndex < self.queue.count && self.queue[self.queueIndex].id == targetTrackId {
                        self.queue[self.queueIndex] = updated
                    }
                    #if os(iOS)
                    let isBackgrounded = UIApplication.shared.applicationState != .active
                    #else
                    let isBackgrounded = false
                    #endif
                    
                    if self.status != .playing || isBackgrounded || streamInfo.isLossless {
                        let currentPos = self.currentTime
                        self.startPlaying(url: streamInfo.streamURL, for: updated, initialSeek: currentPos)
                    }
                }
            }
            
            // Watchdog fallback: if YouTubeAudioBridge doesn't start producing audio within 6.0s, fall back to AVPlayer!
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self = self, self.currentTrack?.id == targetTrackId else { return }
                if self.status != .playing {
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
                    self.status = .loading
                    self.updateNowPlayingInfo()
                    
                    let targetTrackId = vId
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let streamInfo = try? await StreamExtractor.shared.extractAudioStream(trackId: targetTrackId, title: track.title, artist: track.artist) {
                            guard self.currentTrack?.id == targetTrackId else { return }
                            var withStream = updated
                            withStream.streamURL = streamInfo.streamURL
                            withStream.isLossless = streamInfo.isLossless
                            withStream.sampleRate = streamInfo.sampleRate
                            withStream.bitDepth = streamInfo.bitDepth
                            self.currentTrack = withStream
                            if self.queueIndex < self.queue.count && self.queue[self.queueIndex].id == targetTrackId {
                                self.queue[self.queueIndex] = withStream
                            }
                            
                            // Switch to AVPlayer if not playing yet, or if a true Lossless/Hi-Res stream was resolved
                            if self.status != .playing || streamInfo.isLossless {
                                let currentPos = self.currentTime
                                self.startPlaying(url: streamInfo.streamURL, for: withStream, initialSeek: currentPos)
                            }
                        }
                    }
                    
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        guard let self = self, self.currentTrack?.id == targetTrackId else { return }
                        if self.status != .playing {
                            print("[AudioEngine] YouTube Audio Bridge startup timed out for \(targetTrackId), switching to AVPlayer stream fallback")
                            self.attemptStreamFallback(for: updated)
                        }
                    }
                }
            } else if let directURL = track.streamURL, !directURL.absoluteString.contains("apple.com") {
                self.startPlaying(url: directURL, for: track)
            } else {
                self.attemptStreamFallback(for: track)
            }
        }
    }
    
    private func startPlaying(url: URL, for track: Track, initialSeek: TimeInterval = 0) {
        self.activeBackend = .avPlayer
        YouTubeAudioBridge.shared.pause()
        if initialSeek > 0 {
            self.pendingSeekTime = initialSeek
            self.currentTime = initialSeek
        }
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
                    if let seekTime = self.pendingSeekTime, seekTime > 0 {
                        let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
                        self.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        self.currentTime = seekTime
                        self.pendingSeekTime = nil
                    }
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
            
            // 2. Official Topic Video fallback on YouTube bridge (Topic videos always allow embedding)
            if let topicId = await YTMusicClient.shared.resolveTopicVideoId(title: track.title, artist: track.artist), topicId != track.id {
                print("[BitChord AudioEngine] Fallback switching to Topic videoId: \(topicId)")
                var updated = track
                updated.id = topicId
                self.currentTrack = updated
                if self.queueIndex < self.queue.count {
                    self.queue[self.queueIndex] = updated
                }
                self.activeBackend = .youtubeBridge
                self.stopAVPlayer()
                YouTubeAudioBridge.shared.play(videoId: topicId)
                return
            }
            
            // 3. High-Fidelity Multi-source StreamExtractor (Full Length Audio Only)
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
        if status == .idle || status == .error || activeBackend == .none {
            if !queue.isEmpty {
                let resumeTime = pendingSeekTime ?? (currentTime > 2 ? currentTime : nil)
                playTrack(at: queueIndex, initialSeek: resumeTime)
                return
            }
        }
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
        #if os(iOS)
        startKeepAlive()
        #endif
        updateNowPlayingInfo()
    }
    
    public func pause() {
        #if os(iOS)
        pauseKeepAlive()
        #endif
        YouTubeAudioBridge.shared.pause()
        player?.rate = 0.0
        player?.pause()
        status = .paused
        if currentTime > 0 {
            LibraryDatabase.shared.updateLastPlaybackProgress(position: currentTime, duration: duration)
        }
        updateNowPlayingInfo()
    }
    
    public func stop() {
        #if os(iOS)
        pauseKeepAlive()
        #endif
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
    
    public func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        volume = clamped
        player?.volume = clamped
        YouTubeAudioBridge.shared.setVolume(clamped)
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
                guard let self = self, self.activeBackend == .avPlayer else { return }
                if self.pendingSeekTime == nil {
                    let sec = time.seconds
                    if sec.isFinite && !sec.isNaN && sec >= 0 {
                        self.currentTime = sec
                        if abs(sec - self.lastSavedProgressTimestamp) >= 2.0 {
                            self.lastSavedProgressTimestamp = sec
                            LibraryDatabase.shared.updateLastPlaybackProgress(position: sec, duration: self.duration)
                        }
                    }
                }
                
                // Keep actual audio stream duration synchronized (and reject 30s remote preview clips)
                if let item = self.player?.currentItem {
                    let realDuration = item.duration.seconds
                    if realDuration.isFinite && realDuration > 0 {
                        if realDuration < 55,
                           let track = self.currentTrack,
                           track.duration >= 60,
                           !(track.streamURL?.isFileURL ?? false) {
                            // Remote stream was a 30s sample/preview clip: switch to full-length official audio
                            var cleaned = track
                            cleaned.streamURL = nil
                            cleaned.isLossless = false
                            self.currentTrack = cleaned
                            self.stopAVPlayer()
                            self.activeBackend = .youtubeBridge
                            if cleaned.id.count == 11 && !cleaned.id.hasPrefix("yt_") {
                                YouTubeAudioBridge.shared.play(videoId: cleaned.id)
                            } else {
                                Task { @MainActor [weak self] in
                                    guard let self = self else { return }
                                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(title: cleaned.title, artist: cleaned.artist) {
                                        var updated = cleaned
                                        updated.id = topicId
                                        self.currentTrack = updated
                                        YouTubeAudioBridge.shared.play(videoId: topicId)
                                    }
                                }
                            }
                            return
                        } else if abs(self.duration - realDuration) > 0.5 {
                            self.duration = realDuration
                        }
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
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                #if os(iOS)
                self?.beginBackgroundTask()
                #endif
                self?.resume()
            }
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.pause()
            }
            return .success
        }
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.stop()
            }
            return .success
        }
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                #if os(iOS)
                self?.beginBackgroundTask()
                #endif
                self?.togglePlayPause()
            }
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                #if os(iOS)
                self?.beginBackgroundTask()
                #endif
                self?.nextTrack()
            }
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                #if os(iOS)
                self?.beginBackgroundTask()
                #endif
                self?.previousTrack()
            }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let pos = event.positionTime
            DispatchQueue.main.async {
                self?.seek(to: pos)
            }
            return .success
        }
        
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif
        #endif
    }
    
    private func updateNowPlayingInfo() {
        #if canImport(MediaPlayer)
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            #if os(iOS)
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            #endif
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? playbackSpeed : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        
        #if os(iOS)
        switch status {
        case .playing:
            MPNowPlayingInfoCenter.default().playbackState = .playing
        case .paused:
            MPNowPlayingInfoCenter.default().playbackState = .paused
        case .loading:
            MPNowPlayingInfoCenter.default().playbackState = .playing
        case .idle, .error:
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        
        if let cached = cachedArtworkImage, cachedTrackId == track.id {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
        } else if let artworkURL = track.artworkURL {
            loadArtwork(from: artworkURL, for: track.id)
            let defaultArt = makeDefaultArtwork()
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultArt.size) { _ in defaultArt }
        } else {
            let defaultArt = makeDefaultArtwork()
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultArt.size) { _ in defaultArt }
        }
        #endif
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }
    
    #if os(iOS)
    private func makeDefaultArtwork() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.85, green: 0.15, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0).cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
                ctx.cgContext.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: 512, y: 512), options: [])
            }
            
            let config = UIImage.SymbolConfiguration(pointSize: 180, weight: .bold)
            if let icon = UIImage(systemName: "music.note", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconRect = CGRect(x: (512 - icon.size.width) / 2, y: (512 - icon.size.height) / 2, width: icon.size.width, height: icon.size.height)
                icon.draw(in: iconRect)
            }
        }
    }
    #endif
    
    #if os(iOS)
    private func loadArtwork(from url: URL, for trackId: String) {
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                guard let self = self, self.currentTrack?.id == trackId else { return }
                self.cachedArtworkImage = image
                self.cachedTrackId = trackId
                self.updateNowPlayingInfo()
            }
        }
    }
    #endif
    
    // MARK: - Audio Routing & Hardware Device Info
    public var currentOutputDeviceName: String {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        if let first = outputs.first {
            return first.portName
        }
        return "This phone"
        #else
        return "This Mac"
        #endif
    }
    
    public var currentOutputRouteType: String {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        if let first = outputs.first {
            switch first.portType {
            case .builtInSpeaker, .builtInReceiver:
                return "PHONE"
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return "BLUETOOTH"
            case .airPlay:
                return "AIRPLAY"
            case .headphones, .headsetMic:
                return "HEADPHONES"
            default:
                return first.portType.rawValue.uppercased()
            }
        }
        return "PHONE"
        #else
        return "INTERNAL"
        #endif
    }
}
