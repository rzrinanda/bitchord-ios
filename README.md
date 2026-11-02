# BitChord for iOS 🎵

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org)
[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat)](https://developer.apple.com/ios/)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

A high-performance, native iOS client for **BitChord** ([kushagrasinghx/BitChord](https://github.com/kushagrasinghx/BitChord)), designed with Apple Music aesthetic fluidity, bit-perfect lossless audio streaming, syllable-level synchronized lyrics, and switchable offline lyrics caching.

---

## 🌟 Key Features (Identical to Android with iOS Optimizations)

### 1. 🎧 Audio & Playback Engine
* **Lossless & Hi-Res Streaming:** High-resolution audio playback supporting FLAC/ALAC streams up to 24-bit / 192 kHz.
* **Bit-Perfect External USB DAC Mode:** Directly interfaces with external audio hardware, automatically matching hardware sample rates and bypassing operating system resampling.
* **True Gapless Playback:** Prebuffers next queue items for zero latency transitions.
* **Smooth Crossfade (0 - 12s):** Non-blocking logarithmic volume curves between tracks.
* **Automix [Beta]:** Smart transition pacing between tracks.
* **Playback Speed Control:** Real-time speed adjustment from `0.5×` to `2.0×`.
* **Equalizer Presets:** 10-band audio equalization (Flat, Bass Boost, Vocal Booster, Acoustic, Electronic, Rock, Hip-Hop, Jazz, Classical, Treble Booster).
* **Sleep Timer:** Automatic playback stop with smooth volume fade-out.
* **Lock Screen & Control Center:** Full integration with `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter`.

### 2. 📝 Synchronized Lyrics Engine & Switchable Offline Storage (✨ Added Feature)
* **Syllable & Word-Level Synchronization:** Parses advanced LRC formats (`[mm:ss.xx]` and `<mm:ss.xx>` syllable tags) with karaoke-style highlights and smooth spring-scrolling.
* **Multi-Provider Fallback:** Integrated with LRCLIB API and local embedded tags.
* **Switchable Auto-Download to Storage:**
  * **Auto-Download ON:** Every fetched lyric is automatically saved to local device disk storage (`Documents/BitChord/LyricsCache/`) for instant offline viewing.
  * **Auto-Download OFF:** Lyrics are streamed in memory only for the active playback session, leaving the device disk untouched.
  * **Manual Offline Cache:** One-tap button on any track to download lyrics for offline access regardless of auto-download setting.
  * **Cache Management:** Live storage usage readout (e.g. `1.4 MB - 48 tracks`) and one-tap cache purge in Settings.

### 3. 🎨 Native Apple Music Inspired UI
* **Frosted Glass Styling:** Liquid materials (`.ultraThinMaterial`), dynamic borders, and frosted pill dock inspired by BitChord's Haze design.
* **Dynamic Artwork Mesh Gradient:** Fluid background meshes generated dynamically from current track colors.
* **Mini Player Bar:** Floating gesture-driven mini-player with swipe-to-skip and drag-to-expand.
* **Fullscreen Player:** Interactive scrub bar, audio quality badges (`HI-RES LOSSLESS 24-bit/96kHz`), repeat/shuffle controls, and sliding lyrics panel.

### 4. 🌐 Integrations
* **Last.fm & ListenBrainz Scrobbling:** Automatic background scrobbling and Now Playing status updates.
* **Discord Rich Presence:** Real-time track display.

---

## 🏗 Architecture & Project Structure

The project follows Clean Architecture with strict separation between business domain logic and presentation:

```
├── Package.swift
├── Sources/
│   ├── BitChordCore/                    # Pure Domain & Business Engine
│   │   ├── Models/
│   │   │   ├── Track.swift              # Track model, duration & badge formatting
│   │   │   ├── Album.swift              # Album model & track lists
│   │   │   ├── Artist.swift             # Artist model & discography
│   │   │   ├── Playlist.swift           # Playlist container
│   │   │   ├── Lyrics.swift             # Syllable & line-level lyrics structures
│   │   │   ├── AudioQuality.swift       # Quality levels (Lossless, High, Normal, Data Saver)
│   │   │   └── PlaybackState.swift      # Status, Repeat, and Shuffle enums
│   │   ├── AudioEngine/
│   │   │   ├── AudioPlayerEngine.swift  # AVPlayer/AVQueuePlayer, queue & remote controls
│   │   │   ├── CrossfadeManager.swift   # Volume crossfade curves
│   │   │   ├── EqualizerPreset.swift    # 10-band EQ presets
│   │   │   └── SleepTimer.swift         # Sleep timer with fade-out
│   │   ├── Lyrics/
│   │   │   ├── LRCParser.swift          # LRC parser (lines & syllable tags)
│   │   │   ├── LyricsStorageManager.swift # Switchable disk vs in-memory storage manager
│   │   │   ├── LRCLIBClient.swift       # LRCLIB REST client
│   │   │   └── LyricsManager.swift      # Unified lyrics coordinator
│   │   ├── Network/
│   │   │   ├── YTMusicClient.swift      # Innertube search & playback client
│   │   │   ├── StreamExtractor.swift    # Audio stream URL extractor & fallback
│   │   │   └── InnertubeEndpoints.swift # API endpoints & contexts
│   │   └── Services/
│   │       ├── BitChordSettings.swift   # App settings & AppStorage
│   │       ├── LastFmScrobbler.swift    # Last.fm API client
│   │       └── ListenBrainzScrobbler.swift # ListenBrainz client
│   └── BitChordUI/                      # SwiftUI Interface Target
│       ├── Components/
│       │   ├── FrostedGlass.swift       # Ultra-thin material modifiers
│       │   ├── DynamicBackgroundGradient.swift # Fluid ambient meshes
│       │   └── MiniPlayerBar.swift      # Floating player pill
│       ├── Views/
│       │   ├── MainTabView.swift        # 4-tab container with mini player
│       │   ├── HomeView.swift           # Listen Now / Quick Picks
│       │   ├── SearchView.swift         # Innertube catalog search
│       │   ├── LibraryView.swift        # Playlists, Liked Songs & Offline Lyrics
│       │   ├── NowPlayingView.swift     # Fullscreen player & queue sheet
│       │   ├── SyncedLyricsView.swift   # Syllable-synced lyrics viewer
│       │   └── SettingsView.swift       # Audio, Lyrics switch, and Scrobbler settings
│       └── BitChordApp.swift            # iOS App Entry Point
└── Tests/
    └── BitChordTestsRunner/
        └── main.swift                   # Automated test suite (26 assertions)
```

---

## 🧪 Testing

The repository contains an automated test suite verifying:
- LRC timestamp parsing (standard, multi-timestamp, and syllable tags).
- **Auto-Download Switch:**
  - Auto-download ON -> verifies file is written to disk storage.
  - Auto-download OFF -> verifies file is in-memory only and disk is untouched.
  - Manual download -> verifies forcing persistent storage.
  - Disk storage size computation and cache clearing.
- Playback queue ordering, next/previous navigation, repeat, and shuffle.
- Crossfade volume calculations and equalizer frequency curves.

### Run Tests:
```bash
swift run BitChordTestsRunner --build-system native -Xswiftc -module-cache-path -Xswiftc /tmp/clang-module-cache
```

---

## 🚀 Running on iOS (Xcode)

1. Clone the repository:
   ```bash
   git clone https://github.com/rzrinanda/bitchord-ios.git
   cd bitchord-ios
   ```
2. Open the package in Xcode:
   ```bash
   xed .
   # Or open Package.swift directly in Xcode
   ```
3. Select your iOS device or simulator (iOS 17.0+) and press **Run (Cmd + R)**.

---

## 📄 License
This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** to match the upstream BitChord project.
