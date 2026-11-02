import Foundation

public enum AudioQuality: String, CaseIterable, Codable, Sendable {
    case lossless = "Lossless (FLAC/ALAC)"
    case high = "High (256 kbps AAC)"
    case normal = "Normal (128 kbps Opus)"
    case dataSaver = "Data Saver (64 kbps Opus)"
    
    public var bitrate: Int {
        switch self {
        case .lossless: return 1411
        case .high: return 256
        case .normal: return 128
        case .dataSaver: return 64
        }
    }
    
    public var badgeTitle: String {
        switch self {
        case .lossless: return "LOSSLESS"
        case .high: return "HIGH QUALITY"
        case .normal: return "STANDARD"
        case .dataSaver: return "DATA SAVER"
        }
    }
}
