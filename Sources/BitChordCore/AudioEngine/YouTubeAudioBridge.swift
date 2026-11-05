import Foundation
#if canImport(WebKit)
import WebKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import SwiftUI

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
    public var onPlaybackError: (@MainActor (Int) -> Void)?
    
    private override init() {
        super.init()
        #if canImport(WebKit)
        setupWebView()
        #endif
    }
    
    #if canImport(WebKit)
    public func getWebView() -> WKWebView {
        if let wv = self.webView {
            return wv
        }
        setupWebView()
        return self.webView!
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        #endif
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "bridge")
        
        // Multi-frame UserScript (injected into top frame AND all subframes/iframes like YouTube's)
        let spoofScript = """
        (function() {
            // 1. Force Page Visibility APIs to always report visible across all frames
            try {
                Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
                Object.defineProperty(document, 'webkitVisibilityState', { get: function() { return 'visible'; }, configurable: true });
                document.hasFocus = function() { return true; };
            } catch(e) {}
            
            // 2. Intercept and neuter visibilitychange, blur, and pagehide listeners on YouTube frames
            var origAddEventListener = EventTarget.prototype.addEventListener;
            EventTarget.prototype.addEventListener = function(type, listener, options) {
                if (type === 'visibilitychange' || type === 'webkitvisibilitychange' || type === 'pagehide' || type === 'freeze') {
                    return;
                }
                return origAddEventListener.call(this, type, listener, options);
            };
        })();
        """
        
        let userScript = WKUserScript(
            source: spoofScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(userScript)
        config.userContentController = contentController
        
        // Active viewport dimensions so iOS WebKit never throttles media or timers
        let wv = WKWebView(frame: .init(x: 0, y: 0, width: 320, height: 240), configuration: config)
        #if os(iOS)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1"
        wv.isOpaque = true
        wv.backgroundColor = .black
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.backgroundColor = .black
        #elseif os(macOS)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        #endif
        self.webView = wv
        
        loadPlayerHTML()
    }
    
    private func loadPlayerHTML() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body, html { margin:0; padding:0; width:100%; height:100%; background-color:#000; overflow:hidden; }
          #player { width:100%; height:100%; border:none; display:block; }
        </style>
        <script>
        // 1. Spoof visibility so YouTube player never detects background / minimization
        try {
          Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: false });
          Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: false });
          Object.defineProperty(document, 'webkitVisibilityState', { get: function() { return 'visible'; }, configurable: false });
        } catch(e) {}

        window.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        window.addEventListener('pagehide', function(e) { e.stopImmediatePropagation(); }, true);

        if (window.navigator && window.navigator.audioSession) {
          try { window.navigator.audioSession.type = 'playback'; } catch(e) {}
        }
        
        // 2. Active WebAudio keepalive to hold WebKit audio thread open
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (AudioCtx) {
            var aCtx = new AudioCtx();
            window._aCtx = aCtx;
            var osc = aCtx.createOscillator();
            var g = aCtx.createGain();
            g.gain.value = 0.00001;
            osc.connect(g);
            g.connect(aCtx.destination);
            osc.start(0);
          }
        } catch(e) {}
        </script>
        </head>
        <body>
        <iframe id="player"
                src=""
                allow="autoplay; encrypted-media; picture-in-picture"
                playsinline>
        </iframe>
        <script>
        var isReady = true;
        var pendingId = null;
        var currentLoadedId = null;
        var isUserPlaying = false;

        function postCommand(command, args) {
          var iframe = document.getElementById('player');
          if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage(JSON.stringify({
              event: 'command',
              func: command,
              args: args || []
            }), '*');
          }
        }

        function playVideoId(vId) {
          isUserPlaying = true;
          try {
            if (window._aCtx && window._aCtx.state === 'suspended') {
              window._aCtx.resume();
            }
          } catch(e) {}
          if ('mediaSession' in navigator) {
            try { navigator.mediaSession.playbackState = 'playing'; } catch(e) {}
          }
          
          var iframe = document.getElementById('player');
          if (!iframe) {
            pendingId = vId;
            return;
          }
          
          if (currentLoadedId === vId) {
            postCommand('playVideo');
          } else {
            currentLoadedId = vId;
            var embedUrl = "https://www.youtube-nocookie.com/embed/" + vId + "?autoplay=1&playsinline=1&controls=0&rel=0&enablejsapi=1&iv_load_policy=3&widget_referrer=https%3A%2F%2Fwww.youtube.com";
            iframe.src = embedUrl;
          }
          
          // Poll listening handshake to wake up YouTube embed API
          var pingCount = 0;
          var pingInterval = setInterval(function() {
            pingCount++;
            if (!isUserPlaying || pingCount > 10) {
              clearInterval(pingInterval);
              return;
            }
            postCommand('listening');
            postCommand('playVideo');
          }, 350);
        }

        function pauseVideo() {
          isUserPlaying = false;
          if ('mediaSession' in navigator) {
            try { navigator.mediaSession.playbackState = 'paused'; } catch(e) {}
          }
          postCommand('pauseVideo');
        }

        function resumeVideo() {
          isUserPlaying = true;
          try {
            if (window._aCtx && window._aCtx.state === 'suspended') {
              window._aCtx.resume();
            }
          } catch(e) {}
          if ('mediaSession' in navigator) {
            try { navigator.mediaSession.playbackState = 'playing'; } catch(e) {}
          }
          postCommand('playVideo');
        }

        function seekTo(seconds) {
          postCommand('seekTo', [seconds, true]);
        }

        function setVolume(vol) {
          postCommand('setVolume', [vol * 100]);
        }

        // Handle YouTube Embed PostMessages
        window.addEventListener('message', function(event) {
          try {
            var data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
            if (!data) return;

            // State changes: 1 = Playing, 2 = Paused, 3 = Buffering, 0 = Ended, -1 = Unstarted
            if (data.event === 'onStateChange') {
              var st = data.info;
              window.webkit.messageHandlers.bridge.postMessage({ type: 'state', state: st });
            } else if (data.event === 'infoDelivery' && data.info) {
              if (data.info.playerState !== undefined) {
                window.webkit.messageHandlers.bridge.postMessage({ type: 'state', state: data.info.playerState });
              }
              if (data.info.currentTime !== undefined) {
                var cur = data.info.currentTime || 0;
                var dur = data.info.duration || 0;
                if (dur > 0) {
                  window.webkit.messageHandlers.bridge.postMessage({ type: 'time', current: cur, duration: dur });
                }
              }
            } else if (data.event === 'onError') {
              var err = data.info || -1;
              window.webkit.messageHandlers.bridge.postMessage({ type: 'error', code: err });
            }
          } catch(e) {}
        });

        // Notify Swift host that HTML container is fully ready
        window.onload = function() {
          window.webkit.messageHandlers.bridge.postMessage({ type: 'ready' });
          if (pendingId) {
            var p = pendingId;
            pendingId = null;
            playVideoId(p);
          }
        };
        </script>
        </body>
        </html>
        """
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
    #endif
    
    public private(set) var isPausedByUser: Bool = false
    
    public func play(videoId: String) {
        self.isPausedByUser = false
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
    
    public func refreshSession() {
        #if canImport(WebKit)
        loadPlayerHTML()
        #endif
    }
    
    public func pause() {
        self.isPausedByUser = true
        #if canImport(WebKit)
        let script = "pauseVideo();"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        #endif
    }
    
    public func resume() {
        self.isPausedByUser = false
        #if canImport(WebKit)
        let script = "resumeVideo();"
        webView?.evaluateJavaScript(script, completionHandler: nil)
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
                    if self.isPausedByUser {
                        self.pause()
                    } else {
                        self.onPlaybackStateChanged?(.playing)
                    }
                case 2: // Paused
                    if self.isPausedByUser {
                        self.onPlaybackStateChanged?(.paused)
                    } else {
                        // Transient pause during video cueing/switching: resume instead of flipping UI to paused
                        self.resume()
                    }
                case 3: // Buffering
                    if !self.isPausedByUser {
                        self.onPlaybackStateChanged?(.loading)
                    }
                default:
                    break
                }
            }
            
        case "time":
            let current = dict["current"] as? Double ?? 0
            let duration = dict["duration"] as? Double ?? 0
            self.onTimeUpdated?(current, duration)
            
        case "error":
            let code = dict["code"] as? Int ?? -1
            print("[YouTubeAudioBridge] Player Error: \(code)")
            self.onPlaybackError?(code)
            
        default:
            break
        }
    }
}

#if os(iOS)
public struct YouTubeBridgeView: UIViewRepresentable {
    public init() {}
    public func makeUIView(context: Context) -> WKWebView {
        return YouTubeAudioBridge.shared.getWebView()
    }
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#elseif os(macOS)
public struct YouTubeBridgeView: NSViewRepresentable {
    public init() {}
    public func makeNSView(context: Context) -> WKWebView {
        return YouTubeAudioBridge.shared.getWebView()
    }
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif

#endif
