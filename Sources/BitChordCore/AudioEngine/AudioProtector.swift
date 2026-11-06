import Foundation
import Darwin

/// Thread-safe singleton for publishing live real-time audio telemetry metrics
/// from the CoreAudio render thread to the UI without blocking audio I/O.
public final class AudioTelemetryState: @unchecked Sendable {
    public static let shared = AudioTelemetryState()
    
    private var lock = os_unfair_lock_s()
    private var _outputPeak: Float = 0.0
    private var _reductionDb: Float = 0.0
    private var _interventions: UInt64 = 0
    private var _bufferedFrames: UInt64 = 46592
    private var _converterDelay: Float = 262.0
    private var _lastUpdated: Date = Date()
    
    public init() {}
    
    public func update(
        peak: Float,
        reductionDb: Float,
        interventions: UInt64,
        bufferedFrames: UInt64,
        converterDelay: Float
    ) {
        os_unfair_lock_lock(&lock)
        _outputPeak = max(0.0, min(1.0, peak))
        _reductionDb = reductionDb
        _interventions = interventions
        _bufferedFrames = bufferedFrames
        _converterDelay = converterDelay
        _lastUpdated = Date()
        os_unfair_lock_unlock(&lock)
    }
    
    public func reset() {
        os_unfair_lock_lock(&lock)
        _outputPeak = 0.0
        _reductionDb = 0.0
        _interventions = 0
        _bufferedFrames = 46592
        _converterDelay = 262.0
        _lastUpdated = Date()
        os_unfair_lock_unlock(&lock)
    }
    
    public var snapshot: (peak: Float, reductionDb: Float, interventions: UInt64, bufferedFrames: UInt64, converterDelay: Float) {
        os_unfair_lock_lock(&lock)
        let res = (_outputPeak, _reductionDb, _interventions, _bufferedFrames, _converterDelay)
        os_unfair_lock_unlock(&lock)
        return res
    }
}

/// Port of the Rust `Protector` from `bagumamartin/BitChord` (native-core/src/sound.rs).
/// A stereo-linked lookahead peak limiter & safety protector that preserves bit-transparency
/// under 0 dBFS and smoothly attenuates inter-sample overs without digital crackle or harsh clipping.
public struct AudioProtector {
    public struct QueuedFrame {
        public var left: Float = 0.0
        public var right: Float = 0.0
        public var bound: Double = 1.0
        public init(left: Float = 0.0, right: Float = 0.0, bound: Double = 1.0) {
            self.left = left
            self.right = right
            self.bound = bound
        }
    }
    
    public let rate: UInt32
    private var ring: [QueuedFrame]
    private let ringMask: Int
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var count: Int = 0
    
    private var gain: Double = 1.0
    private let release: Double
    private let lookaheadRelease: Double
    
    public private(set) var reductionDb: Float = 0.0
    public private(set) var interventions: UInt64 = 0
    public private(set) var outputPeak: Float = 0.0
    
    public var delayFrames: Int {
        Int(rate) / 200 + 32
    }
    
    public init(rate: UInt32 = 48000) {
        self.rate = rate
        // Circular buffer size: power of two >= delayFrames * 2 (1024 frames)
        let capacity = 1024
        self.ring = Array(repeating: QueuedFrame(), count: capacity)
        self.ringMask = capacity - 1
        self.release = exp(-1.0 / (Double(rate) * 0.150))
        let lookaheadFrames = Double(Int(rate) / 200 + 33)
        self.lookaheadRelease = exp(-lookaheadFrames / (Double(rate) * 0.150))
    }
    
    public mutating func reset() {
        self = AudioProtector(rate: self.rate)
    }
    
    /// Processes interleaved or non-interleaved stereo PCM float samples.
    /// Under 0 dBFS: 100% bit-transparent pass-through (only delayed by `delayFrames`).
    /// Over 0 dBFS: Smooth lookahead gain ramp, updating reductionDb and interventions.
    public mutating func process(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>,
        frameCount: Int,
        enhanced: Bool = false
    ) {
        let ceiling: Double = enhanced ? pow(10.0, -0.5 / 20.0) : 1.0
        var blockPeak: Float = 0.0
        let targetDelay = self.delayFrames
        let attack = max(1, Int(rate) / 200)
        
        for i in 0..<frameCount {
            var l = left[i]
            var r = right[i]
            
            // Check for non-finite values (NaN / Inf)
            if !l.isFinite {
                l = 0.0
                interventions &+= 1
            }
            if !r.isFinite {
                r = 0.0
                interventions &+= 1
            }
            
            let curPeak = max(abs(l), abs(r))
            blockPeak = max(blockPeak, curPeak)
            
            // Push into circular ring
            ring[writeIndex] = QueuedFrame(left: l, right: r, bound: 1.0)
            writeIndex = (writeIndex + 1) & ringMask
            count += 1
            
            let peakDouble = Double(curPeak)
            if peakDouble > ceiling {
                interventions &+= 1
                let target = min(1.0, ceiling / peakDouble / 1.06)
                let n = count
                let projectedGain = 1.0 - (1.0 - gain) * lookaheadRelease
                if projectedGain > target {
                    // Update lookahead bounds for queued frames
                    var idx = (writeIndex - 1) & ringMask
                    for step in 0..<n {
                        let distance = step
                        let bound: Double
                        if distance <= 32 {
                            bound = target
                        } else {
                            bound = min(1.0, target + (1.0 - target) * Double(distance - 32) / Double(attack))
                        }
                        ring[idx].bound = min(ring[idx].bound, bound)
                        idx = (idx - 1) & ringMask
                    }
                }
            }
            
            // If ring buffer has filled beyond lookahead delay, output sample with applied gain
            if count > targetDelay {
                let q = ring[readIndex]
                readIndex = (readIndex + 1) & ringMask
                count -= 1
                
                gain = min(q.bound, 1.0 - (1.0 - gain) * release)
                reductionDb = Float(20.0 * log10(max(1e-12, gain)))
                
                var outL = Float(Double(q.left) * gain)
                var outR = Float(Double(q.right) * gain)
                
                if !outL.isFinite { outL = 0.0 }
                if !outR.isFinite { outR = 0.0 }
                
                if abs(outL) > Float(ceiling) {
                    interventions &+= 1
                    outL = max(-Float(ceiling), min(Float(ceiling), outL))
                }
                if abs(outR) > Float(ceiling) {
                    interventions &+= 1
                    outR = max(-Float(ceiling), min(Float(ceiling), outR))
                }
                
                left[i] = outL
                right[i] = outR
            } else {
                left[i] = 0.0
                right[i] = 0.0
            }
        }
        
        self.outputPeak = blockPeak
    }
}
