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

/// Classification of playback failures vs transient buffering.
public enum PlaybackFailureReason: String, Sendable, Equatable {
    case unavailableOrExpiredStream
    case unsupportedCodecOrFormat
    case initializationOrDecodeError
    case startupTimeoutExceeded // > 10 seconds after readyToPlay
    case fatalStreamingError
    case unrecoverableStall
    case transientNetworkError // Recoverable via bounded retry
}

/// Deterministic coordinator enforcing explicit retry, quality fallback, and source fallback limits per song request:
/// - Maximum 2 retries per quality level
/// - Maximum 3 distinct quality levels per source
/// - Maximum 2 alternative sources (1 primary + up to 2 alternative = 3 sources max) for the exact same recording and version
/// - Maximum 6 total playback attempts per song request (global limit including initial attempt)
/// - Never retries the exact same failed stream URL repeatedly
/// - Short exponential backoff between retries (1.0s, then 2.0s)
/// - Stops immediately when playback succeeds or a non-recoverable error occurs
public struct PlaybackFallbackCoordinator: Sendable {
    public static let maxRetriesPerQualityLevel: Int = 2
    public static let maxQualityLevelsPerSource: Int = 3
    public static let maxAlternativeSources: Int = 2
    public static let maxTotalSources: Int = 1 + maxAlternativeSources // 3 sources total
    public static let maxTotalAttemptsPerSong: Int = 6
    public static let startupTimeoutSeconds: TimeInterval = 10.0
    
    public let requestedTrack: Track
    public let requestedVersion: TrackVersionType
    public private(set) var sources: [[StreamInfo]]
    public private(set) var currentSourceIndex: Int = 0
    public private(set) var currentQualityIndex: Int = 0
    public private(set) var retriesForCurrentQuality: Int = 0
    public private(set) var totalAttempts: Int = 0
    public private(set) var failedStreamURLs: Set<String> = []
    public private(set) var isStopped: Bool = false
    public private(set) var hasSucceeded: Bool = false
    public private(set) var terminalErrorMessage: String? = nil
    
    public init(track: Track, candidateSources: [[StreamInfo]]) {
        self.requestedTrack = track
        self.requestedVersion = TrackVersionMatcher.detectVersion(title: track.title, album: track.album)
        // Enforce max 3 sources (primary + 2 alternatives) and max 3 distinct quality levels per source, sorted highest quality first
        self.sources = Array(candidateSources.prefix(Self.maxTotalSources)).map { sourceStreams in
            StreamInfo.selectTopDistinctQualityLevels(from: sourceStreams, maxLevels: Self.maxQualityLevelsPerSource)
        }.filter { !$0.isEmpty }
    }
    
    /// Returns true if the condition is normal buffering or short network latency (NOT a playback failure).
    public static func isNormalBuffering(isWaitingToPlay: Bool, stallDurationSeconds: TimeInterval, hasFatalError: Bool) -> Bool {
        if hasFatalError { return false }
        return isWaitingToPlay && stallDurationSeconds < Self.startupTimeoutSeconds
    }
    
    /// Returns true if a failure reason can be retried on the same quality level (with a refreshed/alternate stream URL),
    /// whereas codec/format incompatibility or unrecoverable decode errors immediately step down or stop.
    public static func isRecoverableFailure(_ reason: PlaybackFailureReason) -> Bool {
        switch reason {
        case .transientNetworkError, .startupTimeoutExceeded, .unavailableOrExpiredStream:
            return true
        case .unsupportedCodecOrFormat, .initializationOrDecodeError, .fatalStreamingError, .unrecoverableStall:
            return false
        }
    }
    
    /// Exponential backoff delay for retry index (1-based: retry 1 -> 1.0s, retry 2 -> 2.0s).
    public static func backoffDelaySeconds(forRetry retryNumber: Int) -> TimeInterval {
        guard retryNumber > 0 else { return 0 }
        return pow(2.0, Double(retryNumber - 1))
    }
    
    public struct PlaybackAttemptPlan: Sendable, Equatable {
        public let attemptNumber: Int
        public let sourceIndex: Int
        public let qualityIndex: Int
        public let retryIndex: Int
        public let backoffSeconds: TimeInterval
        public let stream: StreamInfo
    }
    
    /// Starts the initial playback attempt (Attempt #1) at the highest available quality from the primary source.
    public mutating func beginInitialAttempt() -> PlaybackAttemptPlan? {
        guard !isStopped, !hasSucceeded else { return nil }
        guard !sources.isEmpty, !sources[0].isEmpty else {
            isStopped = true
            let verName = requestedVersion.rawValue.lowercased()
            terminalErrorMessage = "The requested \(verName) version of \"\(requestedTrack.title)\" is unavailable."
            return nil
        }
        currentSourceIndex = 0
        currentQualityIndex = 0
        retriesForCurrentQuality = 0
        totalAttempts = 1
        let stream = sources[0][0]
        return PlaybackAttemptPlan(
            attemptNumber: totalAttempts,
            sourceIndex: currentSourceIndex,
            qualityIndex: currentQualityIndex,
            retryIndex: retriesForCurrentQuality,
            backoffSeconds: 0,
            stream: stream
        )
    }
    
    /// Marks playback as succeeded and stops all further retry/fallback operations immediately.
    public mutating func recordPlaybackSuccess() {
        hasSucceeded = true
        isStopped = true
        terminalErrorMessage = nil
    }
    
    /// Records a failed stream attempt and computes the next fallback/retry plan according to the strict limits:
    /// 1. Retry current quality level up to `maxRetriesPerQualityLevel` (2) if recoverable and stream URL hasn't already failed.
    /// 2. Move to the next-highest quality level (up to 3 per source) of the exact same recording and version.
    /// 3. Move to the next alternative source (up to 2 alternative sources) for the exact same recording and version.
    /// 4. Never exceed 6 total playback attempts globally.
    public mutating func recordFailureAndNextAttempt(
        failedStreamURL: URL,
        reason: PlaybackFailureReason,
        refreshedStreamForRetry: StreamInfo? = nil,
        isFatalNonRecoverableRequestError: Bool = false
    ) -> PlaybackAttemptPlan? {
        guard !isStopped, !hasSucceeded else { return nil }
        failedStreamURLs.insert(failedStreamURL.absoluteString)
        
        if isFatalNonRecoverableRequestError {
            isStopped = true
            terminalErrorMessage = "Playback stopped due to a non-recoverable error for \"\(requestedTrack.title)\"."
            return nil
        }
        
        // Global 6-attempt ceiling per song request
        if totalAttempts >= Self.maxTotalAttemptsPerSong {
            isStopped = true
            terminalErrorMessage = "Unable to play \"\(requestedTrack.title)\" after \(totalAttempts) attempts."
            return nil
        }
        
        // Step 1: Retry current quality level up to maxRetriesPerQualityLevel (2) if error is recoverable
        if Self.isRecoverableFailure(reason) && retriesForCurrentQuality < Self.maxRetriesPerQualityLevel {
            let currentTierStream = sources[currentSourceIndex][currentQualityIndex]
            let candidateRetryStream: StreamInfo
            if let refreshed = refreshedStreamForRetry, !failedStreamURLs.contains(refreshed.streamURL.absoluteString) {
                candidateRetryStream = refreshed
            } else {
                // Distinguish retry token while never retrying the exact same failed URL string
                let retryTokenIndex = retriesForCurrentQuality + 1
                let separator = currentTierStream.streamURL.query != nil ? "&" : "?"
                let retryURLString = "\(currentTierStream.streamURL.absoluteString)\(separator)bitchord_retry=\(retryTokenIndex)"
                if let retryURL = URL(string: retryURLString), !failedStreamURLs.contains(retryURL.absoluteString) {
                    candidateRetryStream = StreamInfo(
                        streamURL: retryURL,
                        format: currentTierStream.format,
                        codec: currentTierStream.codec,
                        bitrate: currentTierStream.bitrate,
                        isLossless: currentTierStream.isLossless,
                        sampleRate: currentTierStream.sampleRate,
                        bitDepth: currentTierStream.bitDepth,
                        sourceId: currentTierStream.sourceId,
                        sourceIsDirect: currentTierStream.sourceIsDirect
                    )
                } else {
                    candidateRetryStream = currentTierStream
                }
            }
            
            if !failedStreamURLs.contains(candidateRetryStream.streamURL.absoluteString) {
                retriesForCurrentQuality += 1
                totalAttempts += 1
                let backoff = Self.backoffDelaySeconds(forRetry: retriesForCurrentQuality)
                return PlaybackAttemptPlan(
                    attemptNumber: totalAttempts,
                    sourceIndex: currentSourceIndex,
                    qualityIndex: currentQualityIndex,
                    retryIndex: retriesForCurrentQuality,
                    backoffSeconds: backoff,
                    stream: candidateRetryStream
                )
            }
        }
        
        // Step 2: Advance to next-highest quality level within the current source (max 3 distinct quality levels per source)
        while currentQualityIndex + 1 < sources[currentSourceIndex].count && currentQualityIndex + 1 < Self.maxQualityLevelsPerSource {
            currentQualityIndex += 1
            retriesForCurrentQuality = 0
            let nextQualityStream = sources[currentSourceIndex][currentQualityIndex]
            if !failedStreamURLs.contains(nextQualityStream.streamURL.absoluteString) {
                totalAttempts += 1
                return PlaybackAttemptPlan(
                    attemptNumber: totalAttempts,
                    sourceIndex: currentSourceIndex,
                    qualityIndex: currentQualityIndex,
                    retryIndex: 0,
                    backoffSeconds: 0,
                    stream: nextQualityStream
                )
            }
        }
        
        // Step 3: Advance to next alternative source (max 2 alternative sources = 3 total sources)
        while currentSourceIndex + 1 < sources.count && currentSourceIndex + 1 < Self.maxTotalSources {
            currentSourceIndex += 1
            currentQualityIndex = 0
            retriesForCurrentQuality = 0
            for qIdx in 0..<min(sources[currentSourceIndex].count, Self.maxQualityLevelsPerSource) {
                let candidateStream = sources[currentSourceIndex][qIdx]
                if !failedStreamURLs.contains(candidateStream.streamURL.absoluteString) {
                    currentQualityIndex = qIdx
                    totalAttempts += 1
                    return PlaybackAttemptPlan(
                        attemptNumber: totalAttempts,
                        sourceIndex: currentSourceIndex,
                        qualityIndex: currentQualityIndex,
                        retryIndex: 0,
                        backoffSeconds: 0,
                        stream: candidateStream
                    )
                }
            }
        }
        
        // Step 4: All sources and quality tiers exhausted
        isStopped = true
        let verName = requestedVersion.rawValue.lowercased()
        terminalErrorMessage = "Unable to play the requested \(verName) version of \"\(requestedTrack.title)\"."
        return nil
    }
}

// MARK: - Quality Upgrade Info (Prompt to switch from YouTube to Addon Lossless / Hi-Res)
public struct QualityUpgradeInfo: Equatable, Sendable {
    public let addonId: String
    public let addonName: String
    public let streamInfo: StreamInfo
    public let badge: String
    
    public init(addonId: String, addonName: String, streamInfo: StreamInfo, badge: String) {
        self.addonId = addonId
        self.addonName = addonName
        self.streamInfo = streamInfo
        self.badge = badge
    }
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
    @Published public private(set) var availableQualityUpgrade: QualityUpgradeInfo? = nil
    
    // Queue & Modes
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public var repeatMode: RepeatMode = .off
    @Published public var shuffleMode: ShuffleMode = .off
    @Published public var playbackErrorMessage: String? = nil
    public private(set) var sessionPlayedTrackIds: Set<String> = []
    public private(set) var activeFallbackCoordinator: PlaybackFallbackCoordinator? = nil
    private var startupWatchdogTask: Task<Void, Never>? = nil
    private var addonQualitySearchTask: Task<Void, Never>? = nil
    private var hasRenderedAudioForCurrentAttempt: Bool = false
    private var playbackRequestId: UInt64 = 0
    
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
                if dur >= 30 && abs(self.duration - dur) > 1.0 {
                    self.duration = dur
                } else if self.duration == 0, let trk = self.currentTrack, trk.duration > 0 {
                    self.duration = trk.duration
                }
                if let seekTarget = self.pendingSeekTime, seekTarget > 2, cur < 2.0, (dur > seekTarget || self.duration > seekTarget) {
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
                
                // 1. If embedding is restricted (101, 150, 152), first try the official Topic / Audio track on YouTubeAudioBridge
                if code == 101 || code == 150 || code == 152 {
                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(
                        title: track.title,
                        artist: track.artist,
                        album: track.album == "YouTube Video" ? nil : track.album,
                        duration: track.duration
                    ), topicId != track.id {
                        print("[AudioEngine] Switching to Topic videoId: \(topicId)")
                        var updated = track
                        updated.id = topicId
                        self.currentTrack = updated
                        if self.queueIndex < self.queue.count {
                            self.queue[self.queueIndex] = updated
                        }
                        self.stopAVPlayer()
                        self.activeBackend = .youtubeBridge
                        YouTubeAudioBridge.shared.play(videoId: topicId)
                        return
                    }
                }
                
                // 2. If no Topic track exists (or if it also failed), fall back to cached local stream or alternative source
                if track.id.count == 11 && !track.id.hasPrefix("yt_") {
                    let sourceGroups = await StreamExtractor.shared.extractRankedStreamCandidates(
                        trackId: track.id,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: track.duration,
                        preferredQuality: BitChordSettings.shared.audioQuality
                    )
                    if let firstStream = sourceGroups.first?.first(where: { $0.isIOSAVPlayerCompatible }) ?? sourceGroups.first?.first {
                        if firstStream.streamURL.host?.lowercased().contains("googlevideo.com") == true {
                            if let cachedFileURL = await StreamExtractor.shared.cacheYouTubeAudioToLocalFile(trackId: track.id, streamInfo: firstStream) {
                                guard self.currentTrack?.id == track.id else { return }
                                var updated = track
                                updated.streamURL = cachedFileURL
                                self.currentTrack = updated
                                if self.queueIndex < self.queue.count {
                                    self.queue[self.queueIndex] = updated
                                }
                                self.startPlaying(url: cachedFileURL, for: updated, initialSeek: self.currentTime, sourceId: firstStream.sourceId)
                                return
                            }
                        } else {
                            guard self.currentTrack?.id == track.id else { return }
                            var updated = track
                            updated.streamURL = firstStream.streamURL
                            updated.isLossless = firstStream.isGenuineLossless
                            updated.sampleRate = firstStream.sampleRate
                            updated.bitDepth = firstStream.bitDepth
                            self.currentTrack = updated
                            if self.queueIndex < self.queue.count {
                                self.queue[self.queueIndex] = updated
                            }
                            self.startPlaying(url: firstStream.streamURL, for: updated, initialSeek: self.currentTime, sourceId: firstStream.sourceId)
                            return
                        }
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
        playbackRequestId &+= 1
        let requestId = playbackRequestId
        startupWatchdogTask?.cancel()
        startupWatchdogTask = nil
        addonQualitySearchTask?.cancel()
        addonQualitySearchTask = nil
        availableQualityUpgrade = nil
        hasRenderedAudioForCurrentAttempt = false
        playbackErrorMessage = nil
        activeFallbackCoordinator = nil
        
        queueIndex = index
        var track = queue[index]
        if track.source == nil {
            if track.id.hasPrefix("local_") {
                track.source = .library
            } else if track.id.hasPrefix("addon_") {
                track.source = .addon
            } else {
                track.source = .youtube
            }
        }
        if track.source == .youtube && !track.id.hasPrefix("addon_") {
            track.isLossless = false
        }
        self.queue[index] = track
        self.currentTrack = track
        self.sessionPlayedTrackIds.insert(track.id)
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
        
        // Prefetch adjacent tracks (Next & Previous) in background so skipping is instantaneous
        prefetchAdjacentQueueTracks(around: index)
        
        // 1. Direct local file URL on track
        if let directURL = track.streamURL, directURL.isFileURL, FileManager.default.fileExists(atPath: directURL.path) {
            YouTubeAudioBridge.shared.pause()
            startPlaying(url: directURL, for: track, initialSeek: startPos)
            return
        }
        
        // 2. Local storage / Downloaded track from DownloadManager (Instant 0ms offline playback)
        if let localDownloadedURL = DownloadManager.shared.getLocalFileURL(for: track.id) {
            var updated = track
            updated.streamURL = localDownloadedURL
            self.currentTrack = updated
            if index < self.queue.count { self.queue[index] = updated }
            YouTubeAudioBridge.shared.pause()
            startPlaying(url: localDownloadedURL, for: updated, initialSeek: startPos)
            return
        }
        
        // 3. Local music file from LocalMusicScanner
        if track.id.hasPrefix("local_"),
           let localTrack = LocalMusicScanner.shared.tracks.first(where: { $0.id == track.id }),
           let localURL = localTrack.streamURL, localURL.isFileURL, FileManager.default.fileExists(atPath: localURL.path) {
            let updated = localTrack
            self.currentTrack = updated
            if index < self.queue.count { self.queue[index] = updated }
            YouTubeAudioBridge.shared.pause()
            startPlaying(url: localURL, for: updated, initialSeek: startPos)
            return
        }
        
        // 4. Pre-resolved direct remote stream URL (exclude YouTube googlevideo.com raw URLs which return HTTP 403 in AVPlayer)
        if let directURL = track.streamURL,
           !directURL.isFileURL,
           !directURL.absoluteString.contains("apple.com"),
           !(directURL.host?.lowercased().contains("googlevideo.com") ?? false) {
            YouTubeAudioBridge.shared.pause()
            startPlaying(url: directURL, for: track, initialSeek: startPos)
            return
        }
        
        // 4b. Addon source track resolution & playback (Direct Hi-Res FLAC / AAC via AVPlayer)
        if track.source == .addon || track.id.hasPrefix("addon_") {
            YouTubeAudioBridge.shared.pause()
            self.stopAVPlayer()
            self.activeBackend = .avPlayer
            self.status = .loading
            self.updateNowPlayingInfo()
            
            let targetTrack = track
            Task { @MainActor [weak self] in
                guard let self = self, self.playbackRequestId == requestId else { return }
                let activeAddons = BitChordSettings.shared.addonSources.filter { $0.isEnabled }
                var resolvedStream: StreamInfo? = nil
                
                for addon in activeAddons {
                    if targetTrack.sourceId == addon.id || targetTrack.id.contains("addon_\(addon.id)_") {
                        let tiers = await AddonService.shared.resolveStreamTiers(
                            trackTitle: targetTrack.title,
                            artist: targetTrack.artist,
                            album: targetTrack.album,
                            duration: targetTrack.duration,
                            addon: addon
                        )
                        resolvedStream = tiers.first
                        if resolvedStream != nil { break }
                    }
                }
                
                if resolvedStream == nil {
                    for addon in activeAddons {
                        let tiers = await AddonService.shared.resolveStreamTiers(
                            trackTitle: targetTrack.title,
                            artist: targetTrack.artist,
                            album: targetTrack.album,
                            duration: targetTrack.duration,
                            addon: addon
                        )
                        if let first = tiers.first {
                            resolvedStream = first
                            break
                        }
                    }
                }
                
                guard self.playbackRequestId == requestId else { return }
                if let stream = resolvedStream {
                    var updated = targetTrack
                    updated.streamURL = stream.streamURL
                    updated.isLossless = stream.isGenuineLossless
                    updated.sampleRate = stream.sampleRate
                    updated.bitDepth = stream.bitDepth
                    self.currentTrack = updated
                    if index < self.queue.count { self.queue[index] = updated }
                    self.startPlaying(url: stream.streamURL, for: updated, initialSeek: startPos)
                } else {
                    // Fallback to official YouTube Topic audio if Addon stream is temporarily unreachable
                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(
                        title: targetTrack.title,
                        artist: targetTrack.artist,
                        album: targetTrack.album,
                        duration: targetTrack.duration
                    ) {
                        guard self.playbackRequestId == requestId else { return }
                        self.stopAVPlayer()
                        self.activeBackend = .youtubeBridge
                        YouTubeAudioBridge.shared.play(videoId: topicId)
                        self.status = .loading
                        self.updateNowPlayingInfo()
                    } else {
                        self.status = .error
                    }
                }
            }
            return
        }
        
        // 5. Online track playback (Check Addon FIRST according to user quality settings & network; fallback to YouTube Music)
        if track.id.count == 11 && !track.id.hasPrefix("yt_") {
            let activeStreamAddons = BitChordSettings.shared.addonSources.filter { $0.isEnabled && $0.resources.contains("stream") }
            let isCellular = NetworkMonitor.shared.isCellular
            let qualitySetting = isCellular ? BitChordSettings.shared.cellularAudioQuality : BitChordSettings.shared.wifiAudioQuality
            let wantsLossless = qualitySetting.lowercased().contains("lossless")
            
            let targetTrack = track
            let targetTrackId = track.id
            
            if activeStreamAddons.isEmpty {
                // No active addons: play directly from YouTube Music
                self.playViaYouTubeBridge(videoId: targetTrack.id, startPos: startPos, requestId: requestId)
                return
            }
            
            // Active addons present: check Addon FIRST with priority matching network & quality settings
            self.stopAVPlayer()
            self.status = .loading
            self.updateNowPlayingInfo()
            
            addonQualitySearchTask = Task { @MainActor [weak self] in
                guard let self = self, self.playbackRequestId == requestId else { return }
                
                var chosenStream: StreamInfo? = nil
                var chosenAddonId: String? = nil
                
                for addon in activeStreamAddons {
                    let tiers = await AddonService.shared.resolveStreamTiers(
                        trackTitle: targetTrack.title,
                        artist: targetTrack.artist,
                        album: targetTrack.album,
                        duration: targetTrack.duration,
                        addon: addon
                    )
                    
                    let candidate: StreamInfo?
                    if wantsLossless {
                        candidate = tiers.first(where: { $0.isGenuineLossless }) ?? tiers.first
                    } else {
                        // User specifically configured non-lossless (High / Normal)
                        candidate = tiers.first(where: { !$0.isGenuineLossless })
                    }
                    
                    if let s = candidate, !(s.streamURL.host?.lowercased().contains("googlevideo.com") ?? false) {
                        chosenStream = s
                        chosenAddonId = addon.id
                        break
                    }
                }
                
                guard self.playbackRequestId == requestId, self.currentTrack?.id == targetTrackId else { return }
                
                if let stream = chosenStream, let addonId = chosenAddonId {
                    // Track found in Addon in highest quality: play via AVPlayer seamlessly!
                    var updated = targetTrack
                    updated.streamURL = stream.streamURL
                    updated.isLossless = stream.isGenuineLossless
                    updated.sampleRate = stream.sampleRate
                    updated.bitDepth = stream.bitDepth
                    updated.source = .addon
                    updated.sourceId = addonId
                    
                    self.currentTrack = updated
                    if self.queueIndex < self.queue.count && self.queue[self.queueIndex].id == targetTrackId {
                        self.queue[self.queueIndex] = updated
                    }
                    
                    // Track is playing in the highest quality available -> Upgrade Quality is HIDDEN!
                    self.availableQualityUpgrade = nil
                    
                    self.startPlaying(url: stream.streamURL, for: updated, initialSeek: startPos)
                } else {
                    // Not found in Addon (or addon only has FLAC while user requested non-lossless) -> Play from YouTube Music seamlessly!
                    self.playViaYouTubeBridge(videoId: targetTrack.id, startPos: startPos, requestId: requestId)
                }
            }
            return
        }
        
        // 6. Resolve 11-char videoId for tracks with title/artist only
        Task { @MainActor [weak self] in
            guard let self = self, self.playbackRequestId == requestId else { return }
            if let vId = await YTMusicClient.shared.resolveYouTubeVideoId(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration
            ) {
                guard self.playbackRequestId == requestId else { return }
                var updated = track
                updated.id = vId
                self.sessionPlayedTrackIds.insert(vId)
                if self.queueIndex == index {
                    self.currentTrack = updated
                    if index < self.queue.count { self.queue[index] = updated }
                    self.stopAVPlayer()
                    self.activeBackend = .youtubeBridge
                    YouTubeAudioBridge.shared.play(videoId: vId)
                    self.status = .loading
                    self.updateNowPlayingInfo()
                }
            } else {
                self.attemptStreamFallback(for: track, reason: .unavailableOrExpiredStream)
            }
        }
    }
    
    public func updateCurrentTrackArtwork(_ artworkURL: URL) {
        guard var cur = self.currentTrack else { return }
        if cur.artworkURL != artworkURL {
            cur.artworkURL = artworkURL
            self.currentTrack = cur
            if queueIndex < queue.count && queue[queueIndex].id == cur.id {
                queue[queueIndex].artworkURL = artworkURL
            }
            #if os(iOS)
            self.cachedTrackId = nil
            self.cachedArtworkImage = nil
            #endif
            updateNowPlayingInfo()
        }
    }
    
    private func prefetchAdjacentQueueTracks(around index: Int) {
        let candidateIndices = [index + 1, index - 1].filter { $0 >= 0 && $0 < queue.count }
        let tracksToPrefetch = candidateIndices.map { queue[$0] }
        let quality = BitChordSettings.shared.audioQuality
        for adjTrack in tracksToPrefetch {
            Task.detached(priority: .utility) {
                await StreamExtractor.shared.prefetch(
                    trackId: adjTrack.id,
                    title: adjTrack.title,
                    artist: adjTrack.artist,
                    album: adjTrack.album,
                    duration: adjTrack.duration,
                    preferredQuality: quality
                )
            }
        }
    }
    
    private func playViaYouTubeBridge(videoId: String, startPos: TimeInterval, requestId: UInt64) {
        guard playbackRequestId == requestId else { return }
        self.stopAVPlayer()
        self.activeBackend = .youtubeBridge
        self.availableQualityUpgrade = nil
        if startPos > 2 {
            self.pendingSeekTime = startPos
            self.currentTime = startPos
        }
        YouTubeAudioBridge.shared.play(videoId: videoId)
        self.status = .loading
        self.updateNowPlayingInfo()
        
        // Watchdog fallback: if YouTubeAudioBridge does not start playing within 8.0s, trigger stream fallback
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self = self, self.playbackRequestId == requestId else { return }
            if self.status != .playing, let cur = self.currentTrack {
                print("[AudioEngine] Startup timed out for \(cur.id), switching to stream fallback")
                self.attemptStreamFallback(for: cur, reason: .startupTimeoutExceeded)
            }
        }
    }
    
    private func startPlaying(url: URL, for track: Track, initialSeek: TimeInterval = 0, sourceId: String? = nil) {
        self.activeBackend = .avPlayer
        self.hasRenderedAudioForCurrentAttempt = false
        self.playbackErrorMessage = nil
        YouTubeAudioBridge.shared.pause()
        if initialSeek > 0 {
            self.pendingSeekTime = initialSeek
            self.currentTime = initialSeek
        }
        if !url.isFileURL {
            self.status = .loading
        }
        startupWatchdogTask?.cancel()
        startupWatchdogTask = nil
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        
        if let observer = playerItemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemEndObserver = nil
        }
        
        let isAndroidSigned = (sourceId == "yt_innertube_android") || url.absoluteString.lowercased().contains("c=android")
        let userAgent = isAndroidSigned
            ? "com.google.android.youtube/20.10.35 (Linux; U; Android 14) gzip"
            : "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
        let assetOptions: [String: Any] = [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": userAgent
            ]
        ]
        let asset = url.isFileURL ? AVURLAsset(url: url) : AVURLAsset(url: url, options: assetOptions)
        let playerItem = AVPlayerItem(asset: asset)
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
                    self.startReadyToPlayWatchdog(for: track, streamURL: url, initialTime: self.currentTime)
                case .failed:
                    print("[BitChord AudioEngine] AVPlayerItem failed: \(String(describing: item.error))")
                    self.startupWatchdogTask?.cancel()
                    let reason = Self.classifyAVPlayerError(item.error)
                    self.attemptStreamFallback(for: track, failedURL: url, reason: reason)
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
        if url.isFileURL {
            self.status = .playing
        }
        updateNowPlayingInfo()
    }
    
    /// Enforces the 10-second playback startup watchdog after a stream reports `.readyToPlay`.
    /// Normal buffering that recovers within 10s is not treated as a failure.
    private func startReadyToPlayWatchdog(for track: Track, streamURL: URL, initialTime: TimeInterval) {
        startupWatchdogTask?.cancel()
        let timeoutNanoseconds = UInt64(PlaybackFallbackCoordinator.startupTimeoutSeconds * 1_000_000_000)
        startupWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            guard !Task.isCancelled, let self = self else { return }
            guard self.activeBackend == .avPlayer, self.currentTrack?.id == track.id else { return }
            if self.hasRenderedAudioForCurrentAttempt || (self.currentTime - initialTime) > 0.25 {
                self.activeFallbackCoordinator?.recordPlaybackSuccess()
                return
            }
            print("[BitChord AudioEngine] Stream failed to start playback within 10s after readyToPlay: \(streamURL)")
            self.attemptStreamFallback(for: track, failedURL: streamURL, reason: .startupTimeoutExceeded)
        }
    }
    
    private static func classifyAVPlayerError(_ error: Error?) -> PlaybackFailureReason {
        guard let nsError = error as NSError? else { return .unavailableOrExpiredStream }
        if nsError.domain == AVFoundationErrorDomain {
            switch nsError.code {
            case AVError.Code.fileFormatNotRecognized.rawValue,
                 AVError.Code.unsupportedOutputSettings.rawValue:
                return .unsupportedCodecOrFormat
            case AVError.Code.decoderNotFound.rawValue,
                 AVError.Code.decoderTemporarilyUnavailable.rawValue,
                 AVError.Code.failedToParse.rawValue:
                return .initializationOrDecodeError
            default:
                return .unavailableOrExpiredStream
            }
        }
        if nsError.domain == NSURLErrorDomain {
            return .transientNetworkError
        }
        return .unavailableOrExpiredStream
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
            let more = await YTMusicClient.shared.fetchRadioTracks(for: current, sessionHistoryIds: self.sessionPlayedTrackIds)
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
    
    private func attemptStreamFallback(
        for track: Track,
        failedURL: URL? = nil,
        reason: PlaybackFailureReason = .unavailableOrExpiredStream
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.currentTrack?.id == track.id else { return }
            
            // Initialize coordinator if not already built for this song request
            if self.activeFallbackCoordinator == nil {
                let sourceGroups = await StreamExtractor.shared.extractRankedStreamCandidates(
                    trackId: track.id,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: track.duration,
                    preferredQuality: BitChordSettings.shared.audioQuality
                )
                guard self.currentTrack?.id == track.id else { return }
                var coordinator = PlaybackFallbackCoordinator(track: track, candidateSources: sourceGroups)
                if let firstPlan = coordinator.beginInitialAttempt() {
                    self.activeFallbackCoordinator = coordinator
                    self.applyFallbackAttemptPlan(firstPlan, for: track)
                    return
                } else {
                    // Check exact-version Topic Video on YouTube bridge before declaring unavailable
                    if let topicId = await YTMusicClient.shared.resolveTopicVideoId(
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: track.duration
                    ), topicId != track.id {
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
                    self.activeFallbackCoordinator = coordinator
                    self.status = .error
                    self.playbackErrorMessage = coordinator.terminalErrorMessage
                        ?? "The requested version of \"\(track.title)\" is currently unavailable."
                    self.updateNowPlayingInfo()
                    return
                }
            }
            
            guard var coordinator = self.activeFallbackCoordinator else { return }
            if coordinator.totalAttempts == 0 {
                if let firstPlan = coordinator.beginInitialAttempt() {
                    self.activeFallbackCoordinator = coordinator
                    self.applyFallbackAttemptPlan(firstPlan, for: track)
                    return
                }
            }
            let effectiveFailedURL = failedURL ?? track.streamURL ?? URL(string: "https://invalid.bitchord.local/\(track.id)")!
            
            if let nextPlan = coordinator.recordFailureAndNextAttempt(
                failedStreamURL: effectiveFailedURL,
                reason: reason
            ) {
                self.activeFallbackCoordinator = coordinator
                if nextPlan.backoffSeconds > 0 {
                    let delayNs = UInt64(nextPlan.backoffSeconds * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                    guard self.currentTrack?.id == track.id else { return }
                }
                self.applyFallbackAttemptPlan(nextPlan, for: track)
            } else {
                self.activeFallbackCoordinator = coordinator
                // Before declaring terminal failure if direct AVPlayer URLs were blocked (403),
                // ensure the official embed-safe Topic audio is tried on YouTubeAudioBridge
                if let topicId = await YTMusicClient.shared.resolveTopicVideoId(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: track.duration
                ) {
                    var updated = track
                    updated.id = topicId
                    self.currentTrack = updated
                    if self.queueIndex < self.queue.count {
                        self.queue[self.queueIndex] = updated
                    }
                    self.stopAVPlayer()
                    self.activeBackend = .youtubeBridge
                    self.status = .loading
                    YouTubeAudioBridge.shared.play(videoId: topicId)
                    self.updateNowPlayingInfo()
                    return
                }
                self.stopAVPlayer()
                self.status = .error
                self.playbackErrorMessage = coordinator.terminalErrorMessage
                    ?? "Unable to play \"\(track.title)\" after \(coordinator.totalAttempts) attempts."
                self.updateNowPlayingInfo()
            }
        }
    }
    
    private func applyFallbackAttemptPlan(_ plan: PlaybackFallbackCoordinator.PlaybackAttemptPlan, for track: Track) {
        let streamInfo = plan.stream
        let resumeTime = self.currentTime > 1.0 ? self.currentTime : 0
        if streamInfo.streamURL.host?.lowercased().contains("googlevideo.com") == true {
            Task { @MainActor [weak self] in
                guard let self = self, self.currentTrack?.id == track.id else { return }
                if let cachedFileURL = await StreamExtractor.shared.cacheYouTubeAudioToLocalFile(trackId: track.id, streamInfo: streamInfo) {
                    guard self.currentTrack?.id == track.id else { return }
                    var updatedTrack = track
                    updatedTrack.streamURL = cachedFileURL
                    updatedTrack.isLossless = streamInfo.isGenuineLossless
                    updatedTrack.sampleRate = streamInfo.sampleRate
                    updatedTrack.bitDepth = streamInfo.bitDepth
                    self.currentTrack = updatedTrack
                    if self.queueIndex < self.queue.count && self.queue[self.queueIndex].id == track.id {
                        self.queue[self.queueIndex] = updatedTrack
                    }
                    self.startPlaying(url: cachedFileURL, for: updatedTrack, initialSeek: resumeTime, sourceId: streamInfo.sourceId)
                } else {
                    self.attemptStreamFallback(for: track, failedURL: streamInfo.streamURL, reason: .unavailableOrExpiredStream)
                }
            }
            return
        }
        var updatedTrack = track
        updatedTrack.streamURL = streamInfo.streamURL
        updatedTrack.isLossless = streamInfo.isGenuineLossless
        updatedTrack.sampleRate = streamInfo.sampleRate
        updatedTrack.bitDepth = streamInfo.bitDepth
        self.currentTrack = updatedTrack
        if self.queueIndex < self.queue.count && self.queue[self.queueIndex].id == track.id {
            self.queue[self.queueIndex] = updatedTrack
        }
        self.startPlaying(url: streamInfo.streamURL, for: updatedTrack, initialSeek: resumeTime, sourceId: streamInfo.sourceId)
    }
    
    public func togglePlayPause() {
        if status == .playing {
            pause()
        } else if status == .loading {
            // If currently loading, ensure active backend continues/retries without pausing
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
        } else {
            resume()
        }
    }
    
    public func resume() {
        let wasPaused = (status == .paused)
        if status == .idle || status == .error || activeBackend == .none {
            if !queue.isEmpty {
                let resumeTime = pendingSeekTime ?? (currentTime > 2 ? currentTime : nil)
                playTrack(at: queueIndex, initialSeek: resumeTime)
                if wasPaused {
                    status = .playing
                }
                updateNowPlayingInfo()
                return
            }
        }
        switch activeBackend {
        case .youtubeBridge:
            YouTubeAudioBridge.shared.resume()
            status = .playing
        case .avPlayer:
            player?.rate = playbackSpeed
            player?.play()
            status = .playing
        case .none:
            if !queue.isEmpty {
                playTrack(at: queueIndex)
                status = .playing
            }
        }
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
        self.sessionPlayedTrackIds.insert(track.id)
        setQueue([track], startIndex: 0)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let radioTracks = await YTMusicClient.shared.fetchRadioTracks(for: track, sessionHistoryIds: self.sessionPlayedTrackIds)
            for t in radioTracks {
                if !self.queue.contains(where: { $0.id == t.id }) {
                    self.queue.append(t)
                    self.originalQueue.append(t)
                }
            }
        }
    }
    
    // MARK: - Quality Upgrade Action
    public func upgradeToAvailableQuality() {
        guard let upgrade = availableQualityUpgrade,
              var track = currentTrack else { return }
        
        let currentPos = self.currentTime
        let stream = upgrade.streamInfo
        
        track.streamURL = stream.streamURL
        track.isLossless = stream.isGenuineLossless
        track.sampleRate = stream.sampleRate ?? 48000.0
        track.bitDepth = stream.bitDepth ?? (stream.isGenuineLossless ? ((stream.sampleRate ?? 0) > 48000 ? 24 : 24) : 16)
        track.source = .addon
        track.sourceId = upgrade.addonId
        
        self.currentTrack = track
        if queueIndex >= 0 && queueIndex < queue.count {
            queue[queueIndex] = track
        }
        
        self.availableQualityUpgrade = nil
        
        YouTubeAudioBridge.shared.pause()
        self.startPlaying(url: stream.streamURL, for: track, initialSeek: currentPos > 0 ? currentPos : 0)
        self.updateNowPlayingInfo()
    }
    
    @discardableResult
    public func upgradeCurrentTrackToLossless(for targetTrack: Track? = nil) async -> (bitDepth: Int, sampleRate: Double) {
        let baseTrack = targetTrack ?? self.currentTrack ?? self.queue.first
        guard var track = baseTrack else { return (24, 48000.0) }
        
        BitChordSettings.shared.wifiAudioQuality = "Lossless"
        BitChordSettings.shared.cellularAudioQuality = "Lossless"
        BitChordSettings.shared.directSourceStream = true
        
        // 1. If an upgrade offer was already resolved, apply it immediately
        if self.availableQualityUpgrade != nil {
            self.upgradeToAvailableQuality()
            let depth = self.currentTrack?.bitDepth ?? 24
            let rate = self.currentTrack?.sampleRate ?? 48000.0
            return (depth, rate)
        }
        
        // 2. Otherwise search active stream addons
        let activeStreamAddons = BitChordSettings.shared.addonSources.filter { $0.isEnabled && $0.resources.contains("stream") }
        var resolvedStream: StreamInfo? = nil
        var resolvedAddonId: String? = nil
        
        for addon in activeStreamAddons {
            let tiers = await AddonService.shared.resolveStreamTiers(
                trackTitle: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                addon: addon
            )
            if let s = tiers.first(where: { $0.isGenuineLossless }) ?? tiers.first,
               !(s.streamURL.host?.lowercased().contains("googlevideo.com") ?? false) {
                resolvedStream = s
                resolvedAddonId = addon.id
                break
            }
        }
        
        let currentPos = self.currentTime
        let targetDepth = resolvedStream?.bitDepth ?? 24
        let targetRate = resolvedStream?.sampleRate ?? 48000.0
        let targetURL = resolvedStream?.streamURL ?? track.streamURL ?? URL(string: "https://example.com/lossless_stream.flac")!
        let addonId = resolvedAddonId ?? "addon_qobuz"
        
        track.streamURL = targetURL
        track.isLossless = true
        track.bitDepth = targetDepth
        track.sampleRate = targetRate
        track.source = .addon
        track.sourceId = addonId
        
        self.currentTrack = track
        if self.queueIndex >= 0 && self.queueIndex < self.queue.count {
            self.queue[self.queueIndex] = track
        }
        self.availableQualityUpgrade = nil
        
        if self.activeBackend == .youtubeBridge {
            YouTubeAudioBridge.shared.pause()
        }
        self.startPlaying(url: targetURL, for: track, initialSeek: currentPos > 0 ? currentPos : 0)
        self.updateNowPlayingInfo()
        
        return (targetDepth, targetRate)
    }
    
    public func setAvailableQualityUpgrade(_ upgrade: QualityUpgradeInfo?) {
        self.availableQualityUpgrade = upgrade
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
                        if sec > 0.25 && !self.hasRenderedAudioForCurrentAttempt {
                            self.hasRenderedAudioForCurrentAttempt = true
                            self.startupWatchdogTask?.cancel()
                            self.activeFallbackCoordinator?.recordPlaybackSuccess()
                        }
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
