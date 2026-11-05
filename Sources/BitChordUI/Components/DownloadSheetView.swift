import SwiftUI

public struct DownloadSheetView: View {
    public let track: Track
    @Environment(\.dismiss) private var dismiss
    
    // Download source options matching reference screenshot
    public enum DownloadSource: String, CaseIterable, Identifiable {
        case amazonMusic = "Amazon Music"
        case deezer = "Deezer"
        case jioSaavn = "JioSaavn"
        case qobuz = "Qobuz"
        case soundCloud = "SoundCloud"
        case tidal = "Tidal"
        case youTubeMusic = "YouTube Music"
        
        public var id: String { rawValue }
        
        public var hasGreenDot: Bool {
            true
        }
        
        public var iconName: String? {
            switch self {
            case .jioSaavn:
                return "waveform.circle.fill"
            case .youTubeMusic:
                return "play.circle.fill"
            default:
                return nil
            }
        }
    }
    
    // Quality tiers matching reference screenshot
    public struct QualityOption: Identifiable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let icon: String
        
        public static let options: [QualityOption] = [
            QualityOption(
                id: "flac_best",
                title: "FLAC Best Available",
                subtitle: "Best available quality (up to 24-bit/192kHz)",
                icon: "music.note"
            ),
            QualityOption(
                id: "opus_320",
                title: "Opus 320kbps",
                subtitle: "High quality Opus audio at 320kbps",
                icon: "waveform"
            ),
            QualityOption(
                id: "dolby_digital",
                title: "Dolby Digital Plus",
                subtitle: "Dolby Digital Plus surround sound (E-AC-3)",
                icon: "music.note"
            )
        ]
    }
    
    @State private var selectedSource: DownloadSource = .amazonMusic
    @State private var downloadingQualityId: String? = nil
    @State private var downloadStatusMessage: String? = nil
    
    public init(track: Track) {
        self.track = track
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.12, green: 0.14, blue: 0.13)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Track Header (Artwork + Title + Artist)
                        HStack(spacing: 14) {
                            TrackArtworkView(track: track, size: 54, cornerRadius: 12)
                            
                            VStack(alignment: .leading, spacing: 3) {
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        
                        // Status banner if download started
                        if let msg = downloadStatusMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(msg)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .scale))
                        }
                        
                        // MARK: - Section 1: Download Dari
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Download Dari")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            // Flow layout / pills
                            VStack(alignment: .leading, spacing: 8) {
                                // Row 1
                                HStack(spacing: 8) {
                                    sourcePill(.amazonMusic)
                                    sourcePill(.deezer)
                                }
                                
                                // Row 2
                                HStack(spacing: 8) {
                                    sourcePill(.jioSaavn)
                                    sourcePill(.qobuz)
                                }
                                
                                // Row 3
                                HStack(spacing: 8) {
                                    sourcePill(.soundCloud)
                                    sourcePill(.tidal)
                                }
                                
                                // Row 4
                                HStack(spacing: 8) {
                                    sourcePill(.youTubeMusic)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Section 2: Pilih Kualitas
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pilih Kualitas")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(QualityOption.options) { option in
                                    Button {
                                        startDownload(option: option)
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: option.icon)
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(option.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                                
                                                Text(option.subtitle)
                                                    .font(.system(size: 12, weight: .regular))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            if downloadingQualityId == option.id {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(.green)
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 14)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if option.id != QualityOption.options.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.08))
                                            .padding(.leading, 60)
                                            .padding(.trailing, 20)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 24)
                    }
                }
            }
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color(red: 0.12, green: 0.14, blue: 0.13))
        }
    }
    
    // MARK: - Source Pill Builder
    @ViewBuilder
    private func sourcePill(_ source: DownloadSource) -> some View {
        let isSelected = selectedSource == source
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedSource = source
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if let icon = source.iconName {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(source == .jioSaavn ? .cyan : .red)
                }
                
                Text(source.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white)
                
                if source.hasGreenDot {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Download Action
    private func startDownload(option: QualityOption) {
        downloadingQualityId = option.id
        Task {
            let success = (try? await DownloadManager.shared.downloadTrack(track: track)) ?? false
            await MainActor.run {
                withAnimation {
                    downloadingQualityId = nil
                    downloadStatusMessage = success ? "Mengunduh '\(option.title)' dari \(selectedSource.rawValue)..." : "Memulai unduhan..."
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }
}
