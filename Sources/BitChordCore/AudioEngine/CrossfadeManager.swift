import Foundation

public final class CrossfadeManager: Sendable {
    public static let shared = CrossfadeManager()
    
    public init() {}
    
    /// Computes volume multiplier (0.0 to 1.0) during fade out of current track
    public func fadeOutVolume(
        currentTime: TimeInterval,
        duration: TimeInterval,
        crossfadeDuration: TimeInterval
    ) -> Float {
        guard crossfadeDuration > 0 else { return 1.0 }
        let remaining = duration - currentTime
        if remaining <= crossfadeDuration && remaining >= 0 {
            return Float(max(0.0, min(1.0, remaining / crossfadeDuration)))
        }
        return 1.0
    }
    
    /// Computes volume multiplier (0.0 to 1.0) during fade in of new track
    public func fadeInVolume(
        currentTime: TimeInterval,
        crossfadeDuration: TimeInterval
    ) -> Float {
        guard crossfadeDuration > 0 else { return 1.0 }
        if currentTime < crossfadeDuration {
            return Float(max(0.0, min(1.0, currentTime / crossfadeDuration)))
        }
        return 1.0
    }
}
