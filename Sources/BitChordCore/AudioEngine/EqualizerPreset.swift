import Foundation

public struct EqualizerBand: Identifiable, Sendable {
    public var id: Double { frequency }
    public let frequency: Double // Hz
    public var gain: Float       // dB (-12.0 to +12.0)
    
    public init(frequency: Double, gain: Float) {
        self.frequency = frequency
        self.gain = gain
    }
}

public enum EqualizerPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case vocal = "Vocal Booster"
    case acoustic = "Acoustic"
    case electronic = "Electronic"
    case rock = "Rock"
    case hipHop = "Hip-Hop"
    case jazz = "Jazz"
    case classical = "Classical"
    case trebleBoost = "Treble Booster"
    
    public var id: String { rawValue }
    
    public var gains: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost:
            return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .vocal:
            return [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]
        case .acoustic:
            return [3, 2, 1, 1, 2, 2, 3, 3, 2, 2]
        case .electronic:
            return [5, 4, 2, 0, -2, 2, 1, 2, 4, 4]
        case .rock:
            return [5, 3, 2, 0, -1, 0, 2, 3, 4, 4]
        case .hipHop:
            return [6, 5, 3, 1, -1, -1, 1, 2, 3, 3]
        case .jazz:
            return [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]
        case .classical:
            return [4, 3, 2, 2, -1, -1, 0, 2, 3, 3]
        case .trebleBoost:
            return [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]
        }
    }
    
    public static let standardFrequencies: [Double] = [
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
    ]
}
