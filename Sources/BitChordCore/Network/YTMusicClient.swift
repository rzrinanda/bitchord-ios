import Foundation

public actor YTMusicClient {
    public static let shared = YTMusicClient()
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Searches tracks, albums, artists from YouTube Music Innertube API
    public func search(query: String, filter: String? = nil) async throws -> [Track] {
        var body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240401.01.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]
        
        if let filter = filter {
            body["params"] = filter
        }
        
        var request = URLRequest(url: InnertubeEndpoints.searchURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Referer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }
        
        return parseSearchResults(data: data)
    }
    
    /// Parses Innertube search JSON response into standard Track models
    private func parseSearchResults(data: Data) -> [Track] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var results: [Track] = []
        
        // Traverse nested contents
        if let contents = json["contents"] as? [String: Any],
           let tabRenderer = contents["tabbedSearchResultsRenderer"] as? [String: Any],
           let tabs = tabRenderer["tabs"] as? [[String: Any]],
           let firstTab = tabs.first,
           let tabContent = firstTab["tabRenderer"] as? [String: Any],
           let content = tabContent["content"] as? [String: Any],
           let sectionList = content["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            
            for section in sections {
                if let shelf = section["musicShelfRenderer"] as? [String: Any],
                   let shelfContents = shelf["contents"] as? [[String: Any]] {
                    for item in shelfContents {
                        if let responsiveItem = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let track = parseResponsiveItem(responsiveItem) {
                            results.append(track)
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    private func parseResponsiveItem(_ item: [String: Any]) -> Track? {
        guard let flexColumns = item["flexColumns"] as? [[String: Any]],
              let firstCol = flexColumns.first,
              let colRenderer = firstCol["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let textRuns = (colRenderer["text"] as? [String: Any])?["runs"] as? [[String: Any]],
              let titleRun = textRuns.first,
              let title = titleRun["text"] as? String else {
            return nil
        }
        
        var artist = "Unknown Artist"
        var album = ""
        var duration: TimeInterval = 180
        
        if flexColumns.count > 1,
           let secondCol = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let secondRuns = (secondCol["text"] as? [String: Any])?["runs"] as? [[String: Any]] {
            if let aRun = secondRuns.first, let aName = aRun["text"] as? String {
                artist = aName
            }
            if secondRuns.count > 2, let albRun = secondRuns[2]["text"] as? String {
                album = albRun
            }
        }
        
        // Extract videoId
        var videoId = UUID().uuidString
        if let navEndpoint = titleRun["navigationEndpoint"] as? [String: Any],
           let watchEndpoint = navEndpoint["watchEndpoint"] as? [String: Any],
           let vId = watchEndpoint["videoId"] as? String {
            videoId = vId
        }
        
        // Extract artwork thumbnail
        var artworkURL: URL? = nil
        if let thumbnail = item["thumbnail"] as? [String: Any],
           let thumbRenderer = thumbnail["musicThumbnailRenderer"] as? [String: Any],
           let thumbnails = (thumbRenderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            artworkURL = URL(string: urlString)
        }
        
        return Track(
            id: videoId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkURL: artworkURL,
            streamURL: nil,
            isLossless: false
        )
    }
}
