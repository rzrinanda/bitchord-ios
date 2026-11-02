import Foundation

public enum PlaybackStatus: String, Codable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case error
}

public enum RepeatMode: String, CaseIterable, Codable, Sendable {
    case off = "Off"
    case all = "Repeat All"
    case one = "Repeat One"
}

public enum ShuffleMode: String, CaseIterable, Codable, Sendable {
    case off = "Off"
    case on = "On"
}
