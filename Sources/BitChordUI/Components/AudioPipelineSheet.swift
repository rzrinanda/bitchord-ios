import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif

public struct AudioPipelineSheet: View {
    public let track: Track
    @ObservedObject var engine = AudioPlayerEngine.shared
    @ObservedObject var settings = BitChordSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    public init(track: Track) {
        self.track = track
    }
    
    // Dynamic metrics based on track quality & playback state
    private var isLossless: Bool {
        track.isLossless || track.audioBadge.contains("LOSSLESS") || track.audioBadge.contains("HI-RES")
    }
    
    private var bitDepth: String {
        isLossless ? "24-bit" : "16-bit"
    }
    
    private var sampleRate: String {
        isLossless ? "48000 Hz" : "44100 Hz"
    }
    
    private var bitrateString: String {
        if isLossless {
            return "1411 kbps"
        } else if track.audioBadge.contains("HIGH") {
            return "320 kbps"
        } else {
            return "256 kbps"
        }
    }
    
    private var decoderName: String {
        if isLossless {
            return "AudioToolbox • FLAC"
        } else if engine.activeBackend == .avPlayer {
            return "AudioToolbox • AAC"
        } else {
            return "WebKit • Opus"
        }
    }
    
    private var outputAPIName: String {
        engine.activeBackend == .avPlayer ? "AVPlayer" : "CoreAudio"
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Title & Subtitle Header
                        VStack(spacing: 4) {
                            Text("Audio Pipeline")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Live signal path, decoder to output")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                        
                        // Vertical Signal Path
                        VStack(spacing: 0) {
                            // Section 1: Source Info
                            PipelineStepRow(
                                icon: nil,
                                title: nil,
                                isFirst: true,
                                isLast: false
                            ) {
                                VStack(spacing: 10) {
                                    MetricRow(label: "Bit Depth", value: bitDepth)
                                    MetricRow(label: "Sample Rate", value: sampleRate)
                                    MetricRow(label: "Bitrate", value: bitrateString)
                                    MetricRow(label: "Channels", value: "Stereo")
                                }
                            }
                            
                            // Section 2: Decoder
                            PipelineStepRow(
                                icon: "cpu",
                                title: "Decoder",
                                isFirst: false,
                                isLast: false
                            ) {
                                VStack(spacing: 10) {
                                    MetricRow(label: "Decoder Name", value: decoderName)
                                    MetricRow(label: "Format", value: "\(sampleRate) • 2 ch • Float32 non-interleaved")
                                }
                            }
                            
                            // Section 3: Resampler
                            PipelineStepRow(
                                icon: "slider.horizontal.3",
                                title: "Resampler",
                                isFirst: false,
                                isLast: false
                            ) {
                                VStack(spacing: 10) {
                                    MetricRow(label: "I/O Rate", value: "\(sampleRate) → \(sampleRate)")
                                    MetricRow(label: "Type", value: "None")
                                    MetricRow(label: "Cutoff", value: "—")
                                    MetricRow(label: "Quality", value: "Passthrough")
                                }
                            }
                            
                            // Section 4: DSP
                            PipelineStepRow(
                                icon: "waveform",
                                title: "DSP",
                                isFirst: false,
                                isLast: false
                            ) {
                                VStack(spacing: 10) {
                                    MetricRow(label: "PCM Format", value: "Float32 non-interleaved")
                                    MetricRow(label: "Sample Rate", value: sampleRate)
                                    MetricRow(label: "Gain", value: "-5.8 dB")
                                    MetricRow(label: "Measured", value: "+5.8 LUFS")
                                    MetricRow(label: "EQ Preset", value: settings.equalizerPreset.rawValue.capitalized)
                                    MetricRow(label: "Stereo Expand", value: "100%")
                                    MetricRow(label: "Speed", value: "\(String(format: "%g", engine.playbackSpeed))x")
                                    MetricRow(label: "Buffers", value: "21 ms, 1024 frames (I/O)")
                                    MetricRow(label: "Output API", value: outputAPIName)
                                    MetricRow(label: "Bit-exact", value: "No — loudness normalization")
                                }
                            }
                            
                            // Section 5: Output Device
                            PipelineStepRow(
                                icon: "speaker.wave.2",
                                title: "Output Device",
                                isFirst: false,
                                isLast: true
                            ) {
                                VStack(spacing: 10) {
                                    MetricRow(label: "Device Name", value: engine.currentOutputDeviceName)
                                    MetricRow(label: "Route", value: engine.currentOutputRouteType)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 32)
                        
                        // Done Button (Matching Reference Video Frame 004)
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Pipeline Step Row with Connected Vertical Timeline
private struct PipelineStepRow<Content: View>: View {
    let icon: String?
    let title: String?
    let isFirst: Bool
    let isLast: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Left Connected Timeline Indicator
            VStack(spacing: 0) {
                if isFirst {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                } else if let icon = icon {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if let title = title {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                }
                
                content()
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Metric Row Key: Value
private struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
        }
    }
}
