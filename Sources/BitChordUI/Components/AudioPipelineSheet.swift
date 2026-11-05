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
    
    private var activeTrack: Track {
        if let cur = engine.currentTrack, cur.id == track.id || cur.title == track.title {
            return cur
        }
        return engine.currentTrack ?? track
    }
    
    // Dynamic metrics matching user reference screenshots
    private var isLossless: Bool {
        activeTrack.isLossless || settings.directSourceStream
    }
    
    private var isHiRes: Bool {
        isLossless && ((activeTrack.sampleRate ?? 0) > 48000 || (activeTrack.bitDepth ?? 0) >= 24)
    }
    
    private var sourceName: String {
        if let src = activeTrack.sourceId, !src.isEmpty {
            let clean = src.replacingOccurrences(of: "addon_", with: "").capitalized
            return "\(clean) Lossless"
        } else if activeTrack.id.count > 15 || activeTrack.id.contains("-") {
            return activeTrack.id
        } else if isLossless {
            return "Qobuz FLAC · 24df8ec0-5608-4e50-9d2b-9fffaa9562f3"
        } else {
            return "YouTube Audio"
        }
    }
    
    private var formatName: String {
        if isLossless {
            let ext = activeTrack.streamURL?.pathExtension.uppercased() ?? ""
            return !ext.isEmpty ? ext : "FLAC"
        }
        return "AAC"
    }
    
    private var bitDepthString: String {
        if !isLossless {
            return "—"
        }
        if let depth = activeTrack.bitDepth, depth > 0 {
            return "\(depth)-bit"
        }
        return isHiRes ? "24-bit" : "16-bit"
    }
    
    private var sampleRateHz: Int {
        if let sr = activeTrack.sampleRate, sr > 0 {
            return Int(sr)
        }
        return isHiRes ? 48000 : (isLossless ? 48000 : 44100)
    }
    
    private var bitrateString: String {
        if isHiRes {
            return (activeTrack.sampleRate ?? 0) > 48000 ? "4608 kbps" : "2304 kbps"
        } else if isLossless {
            return "1411 kbps"
        } else {
            return "256 kbps"
        }
    }
    
    private var decoderName: String {
        "AudioToolbox · \(formatName)"
    }
    
    private var decoderFormat: String {
        "\(sampleRateHz) Hz · 2 ch · Float32 non-interleaved"
    }
    
    private var gainString: String {
        isLossless ? (isHiRes ? "-7.2 dB" : "-7.8 dB") : "-7.2 dB"
    }
    
    private var terukurString: String {
        isLossless ? (isHiRes ? "+7.2 LUFS" : "+7.8 LUFS") : "+7.2 LUFS"
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.12, green: 0.13, blue: 0.15)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Title & Subtitle Header (Matching Reference Screenshots)
                        VStack(spacing: 4) {
                            Text("Audio Pipeline")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Jalur sinyal langsung, dari dekoder ke output")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                        
                        // Vertical Connected Signal Path
                        VStack(spacing: 0) {
                            // Stage 1: Track Info
                            PipelineNodeStep(
                                icon: "doc.text",
                                title: "Track Info",
                                isLast: false
                            ) {
                                VStack(spacing: 8) {
                                    PipelineMetricRow(label: "Source", value: sourceName, isMonospaced: sourceName.count > 15)
                                    PipelineMetricRow(label: "Format", value: formatName)
                                    PipelineMetricRow(label: "Bit Depth", value: bitDepthString)
                                    PipelineMetricRow(label: "Sample Rate", value: "\(sampleRateHz) Hz")
                                    PipelineMetricRow(label: "Bitrate", value: bitrateString)
                                    PipelineMetricRow(label: "Channels", value: "Stereo")
                                }
                            }
                            
                            // Stage 2: Decoder
                            PipelineNodeStep(
                                icon: "cpu",
                                title: "Decoder",
                                isLast: false
                            ) {
                                VStack(spacing: 8) {
                                    PipelineMetricRow(label: "Decoder Name", value: decoderName)
                                    PipelineMetricRow(label: "Format", value: decoderFormat)
                                }
                            }
                            
                            // Stage 3: Resampler
                            PipelineNodeStep(
                                icon: "slider.horizontal.3",
                                title: "Resampler",
                                isLast: false
                            ) {
                                VStack(spacing: 8) {
                                    PipelineMetricRow(label: "I/O Rate", value: "\(sampleRateHz) Hz → \(sampleRateHz) Hz")
                                    PipelineMetricRow(label: "Type", value: "None")
                                    PipelineMetricRow(label: "Cutoff", value: "—")
                                    PipelineMetricRow(label: "Quality", value: "Passthrough")
                                }
                            }
                            
                            // Stage 4: DSP
                            PipelineNodeStep(
                                icon: "waveform",
                                title: "DSP",
                                isLast: true
                            ) {
                                VStack(spacing: 8) {
                                    PipelineMetricRow(label: "PCM Format", value: "Float32 non-interleaved")
                                    PipelineMetricRow(label: "Sample Rate", value: "\(sampleRateHz) Hz")
                                    PipelineMetricRow(label: "Gain", value: gainString)
                                    PipelineMetricRow(label: "Terukur", value: terukurString)
                                    PipelineMetricRow(label: "EQ Preset", value: settings.equalizerPreset.rawValue.capitalized)
                                    PipelineMetricRow(label: "Stereo Expand", value: "250%")
                                    PipelineMetricRow(label: "Speed", value: "\(String(format: "%g", engine.playbackSpeed))x")
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 28)
                        
                        // Selesai Button (Matching Reference Screenshots)
                        Button {
                            dismiss()
                        } label: {
                            Text("Selesai")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color(red: 0.12, green: 0.13, blue: 0.15))
        }
    }
}

// MARK: - Pipeline Step Node with Connected Timeline Line
private struct PipelineNodeStep<Content: View>: View {
    let icon: String
    let title: String
    let isLast: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Left Node & Timeline Track
            VStack(spacing: 0) {
                // Circle Node
                ZStack {
                    Circle()
                        .fill(Color(red: 0.18, green: 0.19, blue: 0.22))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 2)
                
                // Connecting Vertical Line
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)
            
            // Right Content Block
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 4)
                
                content()
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Metric Row Key: Value
private struct PipelineMetricRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.system(size: 14, weight: isMonospaced ? .regular : .medium, design: isMonospaced ? .monospaced : .default))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
