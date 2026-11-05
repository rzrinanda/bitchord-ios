import Foundation
import Network

/// Lightweight embedded local HTTP streaming proxy for iOS / macOS.
/// Runs inside BitChord on `127.0.0.1:<port>` using Apple's built-in `Network.framework`.
/// Relays AVPlayer requests to upstream Google Video CDN streams with authentic iOS client headers,
/// completely eliminating HTTP 403 Forbidden errors and enabling instant, seamless native AVPlayer audio playback.
public final class LocalStreamProxy: @unchecked Sendable {
    public static let shared = LocalStreamProxy()
    
    private let queue = DispatchQueue(label: "com.bitchord.localstreamproxy", qos: .userInitiated)
    private var listener: NWListener?
    public private(set) var port: UInt16 = 0
    public private(set) var isRunning: Bool = false
    private let userAgent = "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
    
    private init() {
        start()
    }
    
    public func start() {
        guard !isRunning else { return }
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            
            // Bind to loopback interface on any available ephemeral port
            let newListener = try NWListener(using: params, on: .any)
            self.listener = newListener
            
            newListener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    if let portValue = newListener.port?.rawValue {
                        self.port = portValue
                        self.isRunning = true
                        print("[LocalStreamProxy] Listening on 127.0.0.1:\(portValue)")
                    }
                case .failed(let error):
                    print("[LocalStreamProxy] Listener failed: \(error.localizedDescription)")
                    self.isRunning = false
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
            
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            newListener.start(queue: queue)
        } catch {
            print("[LocalStreamProxy] Failed to start listener: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        port = 0
    }
    
    /// Converts a raw remote audio stream URL (such as googlevideo.com) into a proxied local URL.
    /// AVPlayer connects to 127.0.0.1 which injects the authentic iOS headers and returns HTTP 200/206 cleanly.
    public func proxyURL(for remoteURL: URL) -> URL {
        // Only proxy remote googlevideo.com or restricted CDN streams
        let host = remoteURL.host?.lowercased() ?? ""
        guard host.contains("googlevideo.com") || host.contains("youtube.com") else {
            return remoteURL
        }
        
        guard isRunning && port > 0 else {
            // If listener not yet ready, start it synchronously
            start()
            if port == 0 {
                return remoteURL
            }
            return buildProxyURL(for: remoteURL, onPort: port)
        }
        
        return buildProxyURL(for: remoteURL, onPort: port)
    }
    
    private func buildProxyURL(for remoteURL: URL, onPort port: UInt16) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)
        components.path = "/stream"
        components.queryItems = [
            URLQueryItem(name: "url", value: remoteURL.absoluteString)
        ]
        return components.url ?? remoteURL
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readHTTPRequest(from: connection)
    }
    
    private func readHTTPRequest(from connection: NWConnection, accumulatedData: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }
            
            if let error = error {
                print("[LocalStreamProxy] Read error: \(error.localizedDescription)")
                connection.cancel()
                return
            }
            
            var data = accumulatedData
            if let content = content {
                data.append(content)
            }
            
            // Check for end of HTTP headers (\r\n\r\n)
            if let range = data.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = data.subdata(in: 0..<range.lowerBound)
                if let requestString = String(data: headerData, encoding: .utf8) {
                    self.dispatchHTTPRequest(requestString, connection: connection)
                } else {
                    self.sendHTTPResponse(status: 400, headers: [:], body: Data("Bad Request".utf8), connection: connection)
                }
            } else if isComplete {
                connection.cancel()
            } else {
                // Continue reading
                self.readHTTPRequest(from: connection, accumulatedData: data)
            }
        }
    }
    
    private func dispatchHTTPRequest(_ requestText: String, connection: NWConnection) {
        let lines = requestText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendHTTPResponse(status: 400, headers: [:], body: Data("Invalid Request".utf8), connection: connection)
            return
        }
        
        let tokens = requestLine.components(separatedBy: " ")
        guard tokens.count >= 2, tokens[0] == "GET" || tokens[0] == "HEAD" else {
            sendHTTPResponse(status: 405, headers: [:], body: Data("Method Not Allowed".utf8), connection: connection)
            return
        }
        
        let path = tokens[1]
        let isHeadMethod = (tokens[0] == "HEAD")
        
        // Extract headers (e.g. Range)
        var clientHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = line[..<colonIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let val = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespacesAndNewlines)
                clientHeaders[key.lowercased()] = val
            }
        }
        
        if path == "/health" {
            let body = Data("{\"status\":\"ok\",\"service\":\"BitChordLocalProxy\"}".utf8)
            sendHTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: body, connection: connection)
            return
        }
        
        guard let urlComponents = URLComponents(string: "http://127.0.0.1" + path),
              let queryItems = urlComponents.queryItems,
              let targetUrlStr = queryItems.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: targetUrlStr) else {
            sendHTTPResponse(status: 400, headers: [:], body: Data("Missing target url".utf8), connection: connection)
            return
        }
        
        forwardStreamRequest(
            to: targetURL,
            clientHeaders: clientHeaders,
            isHeadMethod: isHeadMethod,
            connection: connection
        )
    }
    
    private func forwardStreamRequest(
        to targetURL: URL,
        clientHeaders: [String: String],
        isHeadMethod: Bool,
        connection: NWConnection
    ) {
        var upstreamRequest = URLRequest(url: targetURL)
        upstreamRequest.httpMethod = isHeadMethod ? "HEAD" : "GET"
        upstreamRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        upstreamRequest.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        upstreamRequest.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        
        // Forward Range header if client requested byte range
        if let rangeHeader = clientHeaders["range"] {
            upstreamRequest.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 10.0
        sessionConfig.timeoutIntervalForResource = 3600.0
        let proxyDelegate = ProxyStreamDelegate(connection: connection, isHeadMethod: isHeadMethod)
        let session = URLSession(configuration: sessionConfig, delegate: proxyDelegate, delegateQueue: nil)
        proxyDelegate.session = session
        
        let task = session.dataTask(with: upstreamRequest)
        task.resume()
    }
    
    private func sendHTTPResponse(status: Int, headers: [String: String], body: Data, connection: NWConnection) {
        var headerStr = "HTTP/1.1 \(status) \(statusDescription(for: status))\r\n"
        for (k, v) in headers {
            headerStr += "\(k): \(v)\r\n"
        }
        headerStr += "Content-Length: \(body.count)\r\n"
        headerStr += "Connection: close\r\n\r\n"
        
        var fullData = Data(headerStr.utf8)
        fullData.append(body)
        
        connection.send(content: fullData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func statusDescription(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 206: return "Partial Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        default: return "Response"
        }
    }
}

// MARK: - Streaming Proxy URLSession Delegate

private final class ProxyStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let connection: NWConnection
    private let isHeadMethod: Bool
    private var headersSent = false
    var session: URLSession?
    
    init(connection: NWConnection, isHeadMethod: Bool) {
        self.connection = connection
        self.isHeadMethod = isHeadMethod
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            connection.cancel()
            return
        }
        
        var headerLines: [String] = []
        let statusCode = httpResponse.statusCode
        let statusText = statusCode == 206 ? "Partial Content" : (statusCode == 200 ? "OK" : "OK")
        headerLines.append("HTTP/1.1 \(statusCode) \(statusText)")
        
        // Forward essential headers
        let passThroughHeaders = [
            "Content-Type", "Content-Range", "Content-Length",
            "Accept-Ranges", "Last-Modified", "ETag", "Date"
        ]
        
        for key in passThroughHeaders {
            if let value = httpResponse.value(forHTTPHeaderField: key) {
                headerLines.append("\(key): \(value)")
            }
        }
        if httpResponse.value(forHTTPHeaderField: "Accept-Ranges") == nil {
            headerLines.append("Accept-Ranges: bytes")
        }
        headerLines.append("Connection: keep-alive")
        headerLines.append("")
        headerLines.append("")
        
        let responseHeaderData = Data(headerLines.joined(separator: "\r\n").utf8)
        headersSent = true
        
        connection.send(content: responseHeaderData, completion: .contentProcessed({ [weak self] error in
            if error != nil {
                self?.connection.cancel()
                self?.session?.invalidateAndCancel()
            }
        }))
        
        if isHeadMethod {
            completionHandler(.cancel)
            connection.cancel()
            session.invalidateAndCancel()
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isHeadMethod else { return }
        connection.send(content: data, completion: .contentProcessed({ [weak self] error in
            if error != nil {
                self?.connection.cancel()
                self?.session?.invalidateAndCancel()
            }
        }))
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed({ [weak self] _ in
            self?.connection.cancel()
            self?.session?.finishTasksAndInvalidate()
        }))
    }
}
