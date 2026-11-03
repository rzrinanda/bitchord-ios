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
            window._bitchordUserPlaying = true;
            
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
            
            // 3. Intercept HTMLVideoElement.prototype.pause so automatic OS backgrounding pauses are ignored when playing
            try {
                var origPause = HTMLVideoElement.prototype.pause;
                HTMLVideoElement.prototype.pause = function() {
                    if (window._bitchordUserPlaying) {
                        return; // Ignore automatic OS background pause
                    }
                    return origPause.apply(this, arguments);
                };
            } catch(e) {}
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
        let wv = WKWebView(frame: .init(x: 0, y: 0, width: 100, height: 100), configuration: config)
        #if os(iOS)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.backgroundColor = .clear
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
          #player { width:100%; height:100%; }
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
        <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var player = null;
        var isReady = false;
        var pendingId = null;
        var isUserPlaying = false;

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
              'origin': 'https://bitchord.app'
            },
            events: {
              'onReady': onPlayerReady,
              'onStateChange': onPlayerStateChange,
              'onError': onPlayerError
            }
          });
        }
        if (window.YT && window.YT.Player) {
          onYouTubeIframeAPIReady();
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
          isUserPlaying = true;
          try {
            if (window._aCtx && window._aCtx.state === 'suspended') {
              window._aCtx.resume();
            }
          } catch(e) {}
          if ('mediaSession' in navigator) {
            try { navigator.mediaSession.playbackState = 'playing'; } catch(e) {}
          }
          if (!isReady || !player || !player.loadVideoById) {
            pendingId = vId;
            return;
          }
          try {
            if (player.unMute) player.unMute();
            if (player.setVolume) player.setVolume(100);
          } catch(e) {}
          player.loadVideoById(vId);
          player.playVideo();
        }

        function pauseVideo() {
          isUserPlaying = false;
          if ('mediaSession' in navigator) {
            try { navigator.mediaSession.playbackState = 'paused'; } catch(e) {}
          }
          if (player && player.pauseVideo) player.pauseVideo();
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
          if (player && player.playVideo) player.playVideo();
        }

        function seekTo(seconds) {
          if (player && player.seekTo) player.seekTo(seconds, true);
        }

        function setVolume(vol) {
          if (player && player.setVolume) player.setVolume(vol * 100);
        }

        function onPlayerStateChange(event) {
          // If paused automatically by OS backgrounding/minimization while user intended playback, force resume!
          if (event.data === 2 && isUserPlaying) {
            if (player && player.playVideo) {
              player.playVideo();
            }
            return;
          }
          
          window.webkit.messageHandlers.bridge.postMessage({ type: 'state', state: event.data });
          if (event.data === 5 && player && player.playVideo) {
            player.playVideo();
          }
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
        }, 250);
        </script>
        </body>
        </html>
        """
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://bitchord.app"))
    }
    #endif
    
    public func play(videoId: String) {
        self.currentVideoId = videoId
        #if canImport(WebKit)
        if !isReady {
            self.pendingVideoId = videoId
            return
        }
        let script = "window._bitchordUserPlaying = true; playVideoId('\(videoId)');"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        #endif
    }
    
    public func refreshSession() {
        #if canImport(WebKit)
        loadPlayerHTML()
        #endif
    }
    
    public func pause() {
        #if canImport(WebKit)
        let script = "window._bitchordUserPlaying = false; pauseVideo();"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        #endif
    }
    
    public func resume() {
        #if canImport(WebKit)
        let script = "window._bitchordUserPlaying = true; resumeVideo();"
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
