import Foundation

public struct SongInfo: Sendable, Equatable {
    public let album: String
    public let releaseDate: String
    public let views: String
    public let likes: String
    public let comments: String
    
    public init(
        album: String = "-",
        releaseDate: String = "-",
        views: String = "-",
        likes: String = "-",
        comments: String = "-"
    ) {
        self.album = album
        self.releaseDate = releaseDate
        self.views = views
        self.likes = likes
        self.comments = comments
    }
}
