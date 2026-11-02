import Foundation

@MainActor
public final class SleepTimer: ObservableObject {
    public static let shared = SleepTimer()
    
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var remainingSeconds: TimeInterval = 0
    
    private var timer: Timer?
    private var completionHandler: (() -> Void)?
    private var fadeDuration: TimeInterval = 15.0
    
    public init() {}
    
    public func start(durationMinutes: Int, onComplete: @escaping () -> Void) {
        stop()
        let totalSeconds = TimeInterval(durationMinutes * 60)
        self.remainingSeconds = totalSeconds
        self.isActive = true
        self.completionHandler = onComplete
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.stop()
                    self.completionHandler?()
                }
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
    }
    
    public var formattedRemainingTime: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
