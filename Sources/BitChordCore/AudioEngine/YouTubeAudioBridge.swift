import Foundation
#if canImport(WebKit)
import WebKit
#endif

@MainActor
public final class YouTubeAudioBridge: NSObject {
    public static let shared = YouTubeAudioBridge()
    
    #if canImport(WebKit)
    private var webView: WKWebView?
    #endif
    
    public private(set) var isReady: Bool = false
    public private(set) var currentVideoId: String?
    private var pendingVideoId: String?
    
    public var onPlaybackEnded: (@MainActor () -> Void)?
    public var onPlaybackStateChanged: (@MainActor (PlaybackStatus) -> Void)?
    public var onTimeUpdated: (@MainActor (TimeInterval, TimeInterval) -> Void)?
    
    private override init() {
        super.init()
        #if canImport(WebKit)
        setupWebView()
        #endif
    }
    
    #if canImport(WebKit)
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "bridge")
        config.userContentController = contentController
        
        // Custom user agent to prevent YouTube embed restrictions
        let wv = WKWebView(frame: .init(x: 0, y: 0, width: 2, height: 2), configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        self.webView = wv
        
        loadPlayerHTML()
    }
    
    private func loadPlayerHTML() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body, html { margin:0; padding:0; width:100%; height:100%; background-color:#000; overflow:hidden; }
          #player { width:100%; height:100%; }
        </style>
        <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var player = null;
        var isReady = false;
        var pendingId = null;

        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '100%',
            width: '100%',
            playerVars: {
              'autoplay': 1,
              'controls': 0,
              'playsinline': 1,
              'rel': 0,
              'fs': 0,
              'disablekb': 1,
              'enablejsapi': 1,
              'origin': 'https://music.youtube.com'
            },
            events: {
              'onReady': onPlayerReady,
              'onStateChange': onPlayerStateChange,
              'onError': onPlayerError
            }
          });
        }

        function onPlayerReady(event) {
          isReady = true;
          window.webkit.messageHandlers.bridge.postMessage({ type: 'ready' });
          if (pendingId) {
            playVideoId(pendingId);
            pendingId = null;
          }
        }

        function playVideoId(vId) {
          if (!isReady || !player) {
            pendingId = vId;
            return;
          }
          player.loadVideoById({ videoId: vId, suggestedQuality: 'highres' });
          player.playVideo();
        }

        function pauseVideo() {
          if (player && player.pauseVideo) player.pauseVideo();
        }

        function resumeVideo() {
          if (player && player.playVideo) player.playVideo();
        }

        function seekTo(seconds) {
          if (player && player.seekTo) player.seekTo(seconds, true);
        }

        function setVolume(vol) {
          if (player && player.setVolume) player.setVolume(vol * 100);
        }

        function onPlayerStateChange(event) {
          // -1: unstarted, 0: ended, 1: playing, 2: paused, 3: buffering, 5: cued
          window.webkit.messageHandlers.bridge.postMessage({ type: 'state', state: event.data });
        }

        function onPlayerError(event) {
          window.webkit.messageHandlers.bridge.postMessage({ type: 'error', code: event.data });
        }

        setInterval(function() {
          if (player && player.getCurrentTime && player.getDuration) {
            var cur = player.getCurrentTime() || 0;
            var dur = player.getDuration() || 0;
            if (dur > 0) {
              window.webkit.messageHandlers.bridge.postMessage({ type: 'time', current: cur, duration: dur });
            }
          }
        }, 200);
        </script>
        </body>
        </html>
        """
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://music.youtube.com"))
    }
    #endif
    
    public func play(videoId: String) {
        self.currentVideoId = videoId
        #if canImport(WebKit)
        if !isReady {
            self.pendingVideoId = videoId
            return
        }
        let script = "playVideoId('\(videoId)');"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        #endif
    }
    
    public func pause() {
        #if canImport(WebKit)
        webView?.evaluateJavaScript("pauseVideo();", completionHandler: nil)
        #endif
    }
    
    public func resume() {
        #if canImport(WebKit)
        webView?.evaluateJavaScript("resumeVideo();", completionHandler: nil)
        #endif
    }
    
    public func seek(to seconds: TimeInterval) {
        #if canImport(WebKit)
        webView?.evaluateJavaScript("seekTo(\(seconds));", completionHandler: nil)
        #endif
    }
    
    public func setVolume(_ volume: Float) {
        #if canImport(WebKit)
        webView?.evaluateJavaScript("setVolume(\(volume));", completionHandler: nil)
        #endif
    }
}

#if canImport(WebKit)
extension YouTubeAudioBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        switch type {
        case "ready":
            self.isReady = true
            if let pending = self.pendingVideoId {
                self.pendingVideoId = nil
                self.play(videoId: pending)
            }
            
        case "state":
            if let state = dict["state"] as? Int {
                switch state {
                case 0: // Ended
                    self.onPlaybackEnded?()
                case 1: // Playing
                    self.onPlaybackStateChanged?(.playing)
                case 2: // Paused
                    self.onPlaybackStateChanged?(.paused)
                case 3: // Buffering
                    self.onPlaybackStateChanged?(.loading)
                default:
                    break
                }
            }
            
        case "time":
            let current = dict["current"] as? Double ?? 0
            let duration = dict["duration"] as? Double ?? 0
            self.onTimeUpdated?(current, duration)
            
        case "error":
            print("[YouTubeAudioBridge] Player Error: \(dict["code"] ?? "unknown")")
            self.onPlaybackStateChanged?(.error)
            
        default:
            break
        }
    }
}
#endif
