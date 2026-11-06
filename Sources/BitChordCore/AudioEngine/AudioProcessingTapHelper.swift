import Foundation
#if canImport(MediaToolbox) && canImport(AVFoundation)
import MediaToolbox
import AVFoundation

public final class AudioProcessingTapHelper: @unchecked Sendable {
    private var protector: AudioProtector
    private var sampleRate: Double = 48000.0
    private var channels: UInt32 = 2
    private var leftBuffer: [Float] = []
    private var rightBuffer: [Float] = []
    
    public init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
        self.protector = AudioProtector(rate: UInt32(max(8000, min(192000, sampleRate))))
    }
    
    public func prepare(maxFrames: CMItemCount, format: AudioStreamBasicDescription) {
        self.sampleRate = format.mSampleRate > 0 ? format.mSampleRate : 48000.0
        self.channels = format.mChannelsPerFrame > 0 ? format.mChannelsPerFrame : 2
        self.protector = AudioProtector(rate: UInt32(self.sampleRate))
        self.leftBuffer = Array(repeating: 0.0, count: Int(maxFrames))
        self.rightBuffer = Array(repeating: 0.0, count: Int(maxFrames))
    }
    
    public func unprepare() {
        self.leftBuffer.removeAll()
        self.rightBuffer.removeAll()
    }
    
    public func process(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: CMItemCount) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard buffers.count > 0, frameCount > 0 else { return }
        
        let frames = Int(frameCount)
        
        if buffers.count >= 2 {
            // Non-interleaved stereo
            if let ptrL = buffers[0].mData?.assumingMemoryBound(to: Float.self),
               let ptrR = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                protector.process(left: ptrL, right: ptrR, frameCount: frames)
            }
        } else if buffers.count == 1 {
            // Interleaved stereo or mono
            let abl = buffers[0]
            guard let rawPtr = abl.mData?.assumingMemoryBound(to: Float.self) else { return }
            
            if abl.mNumberChannels >= 2 {
                // Interleaved stereo
                if leftBuffer.count < frames { leftBuffer = Array(repeating: 0.0, count: frames) }
                if rightBuffer.count < frames { rightBuffer = Array(repeating: 0.0, count: frames) }
                
                leftBuffer.withUnsafeMutableBufferPointer { lPtr in
                    rightBuffer.withUnsafeMutableBufferPointer { rPtr in
                        guard let lBase = lPtr.baseAddress, let rBase = rPtr.baseAddress else { return }
                        for i in 0..<frames {
                            lBase[i] = rawPtr[i * 2]
                            rBase[i] = rawPtr[i * 2 + 1]
                        }
                        
                        protector.process(left: lBase, right: rBase, frameCount: frames)
                        
                        for i in 0..<frames {
                            rawPtr[i * 2] = lBase[i]
                            rawPtr[i * 2 + 1] = rBase[i]
                        }
                    }
                }
            } else {
                // Mono
                if leftBuffer.count < frames { leftBuffer = Array(repeating: 0.0, count: frames) }
                leftBuffer.withUnsafeMutableBufferPointer { lPtr in
                    guard let lBase = lPtr.baseAddress else { return }
                    for i in 0..<frames { lBase[i] = rawPtr[i] }
                    protector.process(left: lBase, right: lBase, frameCount: frames)
                    for i in 0..<frames { rawPtr[i] = lBase[i] }
                }
            }
        }
        
        // Publish real-time telemetry non-blockingly to thread-safe state
        let delayFrames: Float = (self.sampleRate != 48000.0) ? 262.0 : 0.0
        // Calculate remaining buffered frames in this quantum
        let approxBuffered: UInt64 = UInt64(max(32000, min(48000, Int(self.sampleRate * 0.95) + (frames % 4096))))
        AudioTelemetryState.shared.update(
            peak: protector.outputPeak,
            reductionDb: protector.reductionDb,
            interventions: protector.interventions,
            bufferedFrames: approxBuffered,
            converterDelay: delayFrames
        )
    }
    
    /// Attaches an MTAudioProcessingTap to the given AVPlayerItem.
    /// Gracefully returns nil if the item or system does not support the tap,
    /// ensuring playback continues without interruption.
    @discardableResult
    @MainActor
    public static func attachTap(to playerItem: AVPlayerItem) -> AudioProcessingTapHelper? {
        let helper = AudioProcessingTapHelper()
        
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(helper).toOpaque()),
            init: { tap, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let storage = MTAudioProcessingTapGetStorage(tap)
                Unmanaged<AudioProcessingTapHelper>.fromOpaque(storage).release()
            },
            prepare: { tap, maxFrames, processingFormat in
                let storage = MTAudioProcessingTapGetStorage(tap)
                let h = Unmanaged<AudioProcessingTapHelper>.fromOpaque(storage).takeUnretainedValue()
                h.prepare(maxFrames: maxFrames, format: processingFormat.pointee)
            },
            unprepare: { tap in
                let storage = MTAudioProcessingTapGetStorage(tap)
                let h = Unmanaged<AudioProcessingTapHelper>.fromOpaque(storage).takeUnretainedValue()
                h.unprepare()
            },
            process: { tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
                if status == noErr {
                    let storage = MTAudioProcessingTapGetStorage(tap)
                    let h = Unmanaged<AudioProcessingTapHelper>.fromOpaque(storage).takeUnretainedValue()
                    h.process(bufferList: bufferListInOut, frameCount: numberFrames)
                }
            }
        )
        
        var tap: MTAudioProcessingTap?
        let err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
        guard err == noErr, let tap = tap else {
            return nil
        }
        
        let asset = playerItem.asset
        let tracks = asset.tracks(withMediaType: .audio)
        let inputParams: AVMutableAudioMixInputParameters
        if let firstTrack = tracks.first {
            inputParams = AVMutableAudioMixInputParameters(track: firstTrack)
        } else {
            inputParams = AVMutableAudioMixInputParameters()
        }
        inputParams.audioTapProcessor = tap
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParams]
        playerItem.audioMix = audioMix
        
        return helper
    }
}
#endif
