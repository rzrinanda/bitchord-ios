import Foundation

public struct InnertubeContext: Codable, Sendable {
    public struct ClientInfo: Codable, Sendable {
        public let clientName: String
        public let clientVersion: String
        public let hl: String
        public let gl: String
        
        public init(
            clientName: String = "WEB_REMIX",
            clientVersion: String = "1.20240401.01.00",
            hl: String = "en",
            gl: String = "US"
        ) {
            self.clientName = clientName
            self.clientVersion = clientVersion
            self.hl = hl
            self.gl = gl
        }
    }
    
    public let client: ClientInfo
    
    public init(client: ClientInfo = ClientInfo()) {
        self.client = client
    }
}

public struct InnertubeEndpoints {
    public static let baseURL = URL(string: "https://music.youtube.com/youtubei/v1")!
    
    public static var searchURL: URL {
        baseURL.appendingPathComponent("search")
    }
    
    public static var browseURL: URL {
        baseURL.appendingPathComponent("browse")
    }
    
    public static var playerURL: URL {
        baseURL.appendingPathComponent("player")
    }
    
    public static var nextURL: URL {
        baseURL.appendingPathComponent("next")
    }
}
