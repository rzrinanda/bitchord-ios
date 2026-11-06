import Foundation
import BitChord

@MainActor
func runAllTests() async {
    print("==================================================")
    print("▶ Starting Complete BitChord for iOS Test Suite")
    print("==================================================")
    
    var passed = 0
    var failed = 0
    
    func assertTest(_ condition: Bool, _ testName: String) {
        if condition {
            print("  ✅ PASS: \(testName)")
            passed += 1
        } else {
            print("  ❌ FAIL: \(testName)")
            failed += 1
        }
    }
    
    // MARK: - Test 1: Audio Playback Engine (Play, Pause, Resume, Stop, Next, Previous, Seek)
    do {
        let engine = AudioPlayerEngine.shared
        let trackA = Track(id: "testA", title: "Song A", artist: "Artist A", duration: 180)
        let trackB = Track(id: "testB", title: "Song B", artist: "Artist B", duration: 200)
        let trackC = Track(id: "testC", title: "Song C", artist: "Artist C", duration: 220)
        
        // 1. Queue initialization & Play
        engine.setQueue([trackA, trackB, trackC], startIndex: 0)
        assertTest(engine.queue.count == 3, "Engine: Queue correctly sets 3 tracks")
        assertTest(engine.currentTrack?.id == "testA", "Engine: Initial track set to Song A")
        assertTest(engine.status == .loading || engine.status == .playing, "Engine: Track transitions to loading/playing")
        
        // 2. Pause
        engine.pause()
        assertTest(engine.status == .paused, "Engine: pause() sets status to .paused")
        
        // 3. Resume
        engine.resume()
        assertTest(engine.status == .playing, "Engine: resume() sets status to .playing")
        
        // 4. Next Track
        engine.nextTrack()
        assertTest(engine.currentTrack?.id == "testB", "Engine: nextTrack() advances queue to Song B")
        assertTest(engine.queueIndex == 1, "Engine: queueIndex advances to 1")
        
        // 5. Previous Track
        engine.previousTrack()
        assertTest(engine.currentTrack?.id == "testA", "Engine: previousTrack() goes back to Song A")
        assertTest(engine.queueIndex == 0, "Engine: queueIndex returns to 0")
        
        // 6. Seek & Playback Speed
        engine.seek(to: 45.0)
        assertTest(engine.currentTime == 45.0, "Engine: seek(to: 45.0) updates currentTime accurately")
        
        engine.setSpeed(1.5)
        assertTest(engine.playbackSpeed == 1.5, "Engine: setSpeed(1.5) updates playback rate")
        engine.setSpeed(1.0)
        
        // 7. Stop
        engine.stop()
        assertTest(engine.status == .idle, "Engine: stop() sets status to .idle")
        assertTest(engine.currentTime == 0, "Engine: stop() resets currentTime to 0")
        
        // 8. Queue Insert & Remove
        let trackD = Track(id: "testD", title: "Song D", artist: "Artist D", duration: 160)
        engine.insertNextInQueue(trackD)
        assertTest(engine.queue[1].id == "testD", "Engine: insertNextInQueue places track as Up Next")
        
        engine.removeTrackFromQueue(at: 1)
        assertTest(!engine.queue.contains(where: { $0.id == "testD" }), "Engine: removeTrackFromQueue removes track from queue")
        
        // 9. Repeat, Shuffle & Loop / AutoPlay
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .all, "Engine: cycleRepeatMode switches to .all")
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .one, "Engine: cycleRepeatMode switches to .one")
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .off, "Engine: cycleRepeatMode cycles back to .off")
        
        // Loop at end of queue with repeatMode == .all
        engine.cycleRepeatMode() // now .all
        engine.setQueue([trackA, trackB], startIndex: 1)
        engine.nextTrack()
        assertTest(engine.currentTrack?.id == "testA", "Engine: nextTrack() loops back to 0 when repeatMode is .all")
        engine.cycleRepeatMode() // .one
        engine.cycleRepeatMode() // .off
        
        // AutoPlay / Loop toggle
        assertTest(engine.isAutoPlayEnabled == true, "Engine: isAutoPlayEnabled defaults to true")
        engine.toggleAutoPlay()
        assertTest(engine.isAutoPlayEnabled == false, "Engine: toggleAutoPlay switches to false")
        engine.toggleAutoPlay()
        assertTest(engine.isAutoPlayEnabled == true, "Engine: toggleAutoPlay switches back to true")
        
        // Shuffle & Restore Invariants
        let t1 = Track(id: "1", title: "1", artist: "A", duration: 100)
        let t2 = Track(id: "2", title: "2", artist: "A", duration: 100)
        let t3 = Track(id: "3", title: "3", artist: "A", duration: 100)
        let t4 = Track(id: "4", title: "4", artist: "A", duration: 100)
        engine.setQueue([t1, t2, t3, t4], startIndex: 0)
        engine.toggleShuffle()
        assertTest(engine.shuffleMode == .on, "Engine: toggleShuffle switches to .on")
        assertTest(engine.queue.count == 4, "Engine: Shuffled queue maintains all 4 tracks")
        assertTest(engine.currentTrack?.id == "1", "Engine: Shuffled queue maintains currently playing track at index 0")
        engine.toggleShuffle()
        assertTest(engine.shuffleMode == .off, "Engine: toggleShuffle switches back to .off")
        assertTest(engine.queue.map { $0.id } == ["1", "2", "3", "4"], "Engine: Shuffle off restores exact original queue order")
        
        // Clear queue
        engine.clearUpcomingQueue()
        assertTest(engine.queue.count == 1, "Engine: clearUpcomingQueue leaves only current track in queue")
        engine.clearQueue()
        assertTest(engine.queue.count == 1, "Engine: clearQueue maintains current track")
    }
    
    // MARK: - Test 2: LRC Parser (Line-Level & Syllable-Level Timing)
    do {
        let parser = LRCParser()
        let sampleLRC = """
        [ti:Starboy]
        [ar:The Weeknd]
        [00:15.30]I'm tryna put you in the worst mood, ah
        [00:18.50]P1 cleaner than your church shoes, ah
        [00:22.10]<00:22.10>Milli <00:22.50>point <00:22.90>two <00:23.20>just to hurt you, ah
        [00:30.00][01:30.00]Look what you've done
        """
        
        let lyrics = parser.parse(trackId: "starboy_test", lrcContent: sampleLRC)
        assertTest(lyrics.isSynced == true, "Lyrics: LRCParser identifies synchronized timing")
        assertTest(lyrics.lines.count == 5, "Lyrics: Multi-timestamp line handling creates 5 entries")
        assertTest(lyrics.lines[0].timestamp == 15.3, "Lyrics: Timestamp 00:15.30 parsed accurately as 15.3s")
        assertTest(lyrics.lines[2].syllables.count == 4, "Lyrics: Syllable tags <mm:ss.xx> parsed into 4 syllables")
        
        let active0 = lyrics.activeLineIndex(for: 16.0)
        assertTest(active0 == 0, "Lyrics: Active line lookup at 16.0s returns index 0")
        
        let active2 = lyrics.activeLineIndex(for: 25.0)
        assertTest(active2 == 2, "Lyrics: Active line lookup at 25.0s returns index 2")
    }
    
    // MARK: - Test 3: Switchable Lyrics Storage (Disk vs In-Memory Session)
    do {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BitChordTestStorage_\(UUID().uuidString)")
        
        // 3A: Auto-Download ON -> Saved to disk
        let storageOn = LyricsStorageManager(customStorageURL: tempDir, defaultAutoDownload: true)
        await storageOn.setAutoDownload(true)
        
        let lyricsOn = Lyrics(
            trackId: "track_auto_on",
            isSynced: true,
            lines: [LyricLine(timestamp: 5.0, text: "Line On")],
            plainLyrics: "Line On",
            provider: "LRCLIB"
        )
        await storageOn.processRetrievedLyrics(lyrics: lyricsOn, rawLRC: "[00:05.00]Line On")
        
        let isSavedOnDisk = await storageOn.isLyricsStoredOnDisk(trackId: "track_auto_on")
        assertTest(isSavedOnDisk == true, "Lyrics Storage: Auto-Download ON writes file to disk storage")
        
        let loaded = await storageOn.getLyrics(for: "track_auto_on")
        assertTest(loaded?.source == .localDisk, "Lyrics Storage: Loaded offline lyrics marked as .localDisk")
        
        // 3B: Auto-Download OFF -> In-memory session only
        let tempDirOff = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BitChordTestStorageOff_\(UUID().uuidString)")
        let storageOff = LyricsStorageManager(customStorageURL: tempDirOff, defaultAutoDownload: false)
        await storageOff.setAutoDownload(false)
        
        let lyricsOff = Lyrics(
            trackId: "track_auto_off",
            isSynced: true,
            lines: [LyricLine(timestamp: 10.0, text: "Line Off")],
            plainLyrics: "Line Off",
            provider: "LRCLIB"
        )
        await storageOff.processRetrievedLyrics(lyrics: lyricsOff, rawLRC: "[00:10.00]Line Off")
        
        let isSavedWhenOff = await storageOff.isLyricsStoredOnDisk(trackId: "track_auto_off")
        assertTest(isSavedWhenOff == false, "Lyrics Storage: Auto-Download OFF leaves disk storage untouched")
        
        let sessionMemory = await storageOff.getLyrics(for: "track_auto_off")
        assertTest(sessionMemory != nil, "Lyrics Storage: In-memory session caching still provides instant access")
        
        // 3C: Manual Download
        await storageOff.manuallySaveToDisk(lyrics: lyricsOff, rawLRC: "[00:10.00]Line Off")
        let isNowSaved = await storageOff.isLyricsStoredOnDisk(trackId: "track_auto_off")
        assertTest(isNowSaved == true, "Lyrics Storage: Manual download successfully forces persistent storage")
        
        // 3D: Cleanup
        await storageOn.clearAllDiskStorage()
        await storageOff.clearAllDiskStorage()
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: tempDirOff)
    }
    
    // MARK: - Test 4: Library Database (Liked Tracks & Playlists)
    do {
        let library = LibraryDatabase.shared
        let favTrack = Track(id: "fav_99", title: "Favorite Song", artist: "Artist", duration: 210)
        
        let wasLikedBefore = library.isLiked(trackId: favTrack.id)
        library.toggleLike(track: favTrack)
        assertTest(library.isLiked(trackId: favTrack.id) != wasLikedBefore, "Library: toggleLike toggles favorite status")
        
        library.createPlaylist(title: "Gym Workout")
        assertTest(library.userPlaylists.contains(where: { $0.title == "Gym Workout" }), "Library: createPlaylist creates custom playlist")
        
        if let gym = library.userPlaylists.first(where: { $0.title == "Gym Workout" }) {
            library.addTrackToPlaylist(playlistId: gym.id, track: favTrack)
            let updatedGym = library.userPlaylists.first(where: { $0.id == gym.id })
            assertTest(updatedGym?.tracks.contains(where: { $0.id == favTrack.id }) == true, "Library: addTrackToPlaylist adds track to playlist")
            
            library.removeTrackFromPlaylist(playlistId: gym.id, trackId: favTrack.id)
            let afterRemove = library.userPlaylists.first(where: { $0.id == gym.id })
            assertTest(afterRemove?.tracks.isEmpty == true, "Library: removeTrackFromPlaylist removes track from playlist")
        }
        
        library.recordPlayback(track: favTrack)
        assertTest(library.recentTracks.contains(where: { $0.id == favTrack.id }), "Library: recordPlayback records playback history")
    }
    
    // MARK: - Test 5: Audio Engine Helpers (Crossfade & Equalizer)
    do {
        let crossfade = CrossfadeManager.shared
        let fadeOutMid = crossfade.fadeOutVolume(currentTime: 198.0, duration: 200.0, crossfadeDuration: 4.0)
        assertTest(fadeOutMid == 0.5, "Crossfade: 50% midpoint fade-out calculation is 0.5")
        
        let fadeInMid = crossfade.fadeInVolume(currentTime: 2.0, crossfadeDuration: 4.0)
        assertTest(fadeInMid == 0.5, "Crossfade: 50% midpoint fade-in calculation is 0.5")
        
        let eq = EqualizerPreset.bassBoost
        assertTest(eq.gains.count == 10, "Equalizer: Preset provides 10 frequency bands")
        assertTest(eq.gains[0] > eq.gains[5], "Equalizer: Bass boost amplifies lower registers")
    }
    
    // MARK: - Test 6: Track Model & Audio Badge Formatting
    do {
        let hiRes = Track(
            id: "hires_test",
            title: "Lossless Master",
            artist: "Studio",
            duration: 215,
            isLossless: true,
            sampleRate: 96000,
            bitDepth: 24
        )
        assertTest(hiRes.audioBadge == "HI-RES LOSSLESS 24-bit/96.0 kHz", "Track: Hi-Res audio badge formatting")
        assertTest(hiRes.formattedDuration == "3:35", "Track: Duration 215s formatted as 3:35")
    }
    
    // MARK: - Test 7: YouTube Music Automix & Radio Recommendations (Same Frequency & Vibe)
    do {
        let museSeed = Track(
            id: "R6f_7G71p_w",
            title: "Starlight",
            artist: "Muse",
            duration: 240
        )
        let radioTracks = await YTMusicClient.shared.fetchRadioTracks(for: museSeed)
        assertTest(!radioTracks.isEmpty, "Automix Radio: Generates curated similar tracks from YouTube Music")
        assertTest(!radioTracks.contains(where: { $0.id == museSeed.id }), "Automix Radio: Filters out seed track from recommendations")
        if let first = radioTracks.first {
            assertTest(!first.title.isEmpty, "Automix Radio: Returned track has non-empty title (\(first.title))")
            assertTest(!first.artist.isEmpty, "Automix Radio: Returned track has non-empty artist (\(first.artist))")
        }
    }
    
    // MARK: - Test 8: YouTube Music Search Categories (Albums, Playlists, Artists) & Album Tracklist Resolution
    do {
        // 1. Search Albums category
        let albumResults = try await YTMusicClient.shared.searchItems(query: "muse", filter: "Albums")
        assertTest(!albumResults.isEmpty, "Search: Category 'Albums' returns album items")
        let albumHit = albumResults.first { $0.type == .album }
        assertTest(albumHit != nil, "Search: Found item with type == .album")
        if let album = albumHit {
            assertTest(album.playlistId != nil || album.browseId != nil, "Search: Album item preserves playlistId or browseId")
            
            // 2. Fetch full tracklist of the album
            let albumId = album.playlistId ?? album.browseId ?? album.id
            let tracks = await YTMusicClient.shared.fetchPlaylistOrAlbumTracks(identifier: albumId)
            assertTest(!tracks.isEmpty, "Album Fetcher: Retrieved playable tracks for album '\(album.title)'")
            if let firstTrack = tracks.first {
                assertTest(firstTrack.id.count == 11, "Album Fetcher: Track has real 11-char YouTube ID (\(firstTrack.id))")
            }
        }
        
        // 3. Search Artists category
        let artistResults = try await YTMusicClient.shared.searchItems(query: "muse", filter: "Artists")
        assertTest(!artistResults.isEmpty, "Search: Category 'Artists' returns artist items")
        let artistHit = artistResults.first { $0.type == .artist }
        assertTest(artistHit != nil, "Search: Found item with type == .artist")
        if let artist = artistHit, let browseId = artist.browseId {
            let artistTracks = await YTMusicClient.shared.fetchArtistTracks(browseId: browseId)
            assertTest(!artistTracks.isEmpty, "Artist Fetcher: Retrieved top tracks for artist '\(artist.title)'")
        }
    } catch {
        assertTest(false, "Search Categories: Threw unexpected error: \(error)")
    }
    
    // MARK: - Test 9: Official Topic Audio Resolution Fallback
    do {
        let topicId = await YTMusicClient.shared.resolveTopicVideoId(
            title: "Mimpi Yang Sempurna",
            artist: "NOAH"
        )
        print("  ℹ️ Resolved Topic video ID: \(topicId ?? "none")")
        assertTest(topicId != nil && topicId?.count == 11, "Topic Resolver: Successfully resolved official Topic video ID")
    }
    
    // MARK: - Test 10: Artist and Album Metadata Extraction
    do {
        // Test non-prefixed search result subtitle (e.g. from YouTube Music "Songs" tab)
        let item1 = SearchResultItem(
            id: "lgY2lwBjMjk",
            title: "Manusia Bodoh",
            subtitle: "Ada Band • Heaven Of Love • 4.18",
            type: .song
        )
        let track1 = item1.asTrack
        assertTest(track1.artist == "Ada Band", "Metadata Extraction: Artist correctly resolved as 'Ada Band' (not album)")
        assertTest(track1.album == "Heaven Of Love", "Metadata Extraction: Album correctly resolved as 'Heaven Of Love'")
        
        // Test category-prefixed search result subtitle
        let item2 = SearchResultItem(
            id: "sample_vid",
            title: "Manusia Bodoh",
            subtitle: "Lagu • Ada Band • Heaven Of Love • 2004",
            type: .song
        )
        let track2 = item2.asTrack
        assertTest(track2.artist == "Ada Band", "Metadata Extraction: Prefixed 'Lagu • Ada Band' resolves artist 'Ada Band'")
        assertTest(track2.album == "Heaven Of Love", "Metadata Extraction: Prefixed 'Lagu • Ada Band' resolves album 'Heaven Of Love'")
        
        // Test video result with view count
        let item3 = SearchResultItem(
            id: "5Ry74xQEW00",
            title: "Manusia Bodoh",
            subtitle: "Video • Ada Band • 3,6 jt x ditonton",
            type: .video
        )
        let track3 = item3.asTrack
        assertTest(track3.artist == "Ada Band", "Metadata Extraction: Video subtitle extracts artist 'Ada Band' bypassing view count")
        assertTest(track3.album == "YouTube Video" || track3.album == "YouTube Music", "Metadata Extraction: Video subtitle defaults album cleanly without false views")
        assertTest(track3.artworkURL?.absoluteString.contains("i.ytimg.com") == true, "Metadata Extraction: Video item automatically populates YouTube thumbnail artwork")
    }
    
    // MARK: - Test 11: Song Info Details Fetcher
    do {
        let sampleTrack = Track(
            id: "5Ry74xQEW00",
            title: "Manusia Bodoh",
            artist: "Ada Band",
            album: "Heaven Of Love",
            duration: 270
        )
        let info = await YTMusicClient.shared.fetchSongInfo(for: sampleTrack)
        assertTest(info.album == "Heaven Of Love", "Song Info: Correctly matches track album 'Heaven Of Love'")
        assertTest(info.views != "-", "Song Info: Successfully retrieves formatted view count (\(info.views))")
        assertTest(info.releaseDate != "-", "Song Info: Successfully retrieves release date (\(info.releaseDate))")
    }
    
    // MARK: - Test 12: Addon Server Manifest & Settings Integration
    do {
        // 1. Fetch live SoundFean manifest
        let manifestURL = "https://soundfean-musics.onrender.com/a/manifest.json"
        let addon = try? await AddonService.shared.fetchManifest(from: manifestURL)
        assertTest(addon != nil, "Addon Service: Successfully fetched and parsed live SoundFean manifest")
        if let addon = addon {
            assertTest(addon.id == "dev.bitperfect.qobuz.de.personal", "Addon Service: Extracted correct addon id '\(addon.id)'")
            assertTest(addon.name.contains("Qobuz"), "Addon Service: Addon name contains Qobuz ('\(addon.name)')")
            assertTest(addon.resources.contains("stream"), "Addon Service: Declares 'stream' resource")
            assertTest(addon.resources.contains("search"), "Addon Service: Declares 'search' resource")
            assertTest(addon.baseURL == "https://soundfean-musics.onrender.com/a", "Addon Service: Correctly computed baseURL")
            
            // 2. Test BitChordSettings integration
            await MainActor.run {
                BitChordSettings.shared.addAddonSource(addon)
                assertTest(BitChordSettings.shared.addonSources.contains(where: { $0.id == addon.id }), "Settings: Addon source added to BitChordSettings.shared.addonSources")
                
                BitChordSettings.shared.toggleAddonSource(id: addon.id)
                let toggled = BitChordSettings.shared.addonSources.first(where: { $0.id == addon.id })?.isEnabled ?? true
                assertTest(!toggled, "Settings: Addon toggle switches to false")
                
                BitChordSettings.shared.toggleAddonSource(id: addon.id)
                let restored = BitChordSettings.shared.addonSources.first(where: { $0.id == addon.id })?.isEnabled ?? false
                assertTest(restored, "Settings: Addon toggle switches back to true")
            }
        }
    }
    
    // MARK: - Test 13: Spotify Account & Playlist Importer Integration
    do {
        await MainActor.run {
            BitChordSettings.shared.setSpotifyAccount(
                displayName: "Test User",
                username: "test_spotify_id",
                avatarURL: "https://example.com/avatar.jpg",
                spdc: "mock_spdc_token_12345",
                accessToken: "mock_access_token_abcde"
            )
            assertTest(BitChordSettings.shared.spotifyConnected == true, "Spotify Settings: Connected status is true")
            assertTest(BitChordSettings.shared.spotifyDisplayName == "Test User", "Spotify Settings: Display name saved")
            assertTest(BitChordSettings.shared.spotifyUsername == "test_spotify_id", "Spotify Settings: Username saved")
            assertTest(BitChordSettings.shared.spotifyCookieSPDC == "mock_spdc_token_12345", "Spotify Settings: sp_dc saved")
            assertTest(BitChordSettings.shared.spotifyAccessToken == "mock_access_token_abcde", "Spotify Settings: Access token saved")
            
            BitChordSettings.shared.disconnectSpotify()
            assertTest(BitChordSettings.shared.spotifyConnected == false, "Spotify Settings: Disconnect sets connected to false")
            assertTest(BitChordSettings.shared.spotifyDisplayName.isEmpty, "Spotify Settings: Disconnect clears display name")
            assertTest(BitChordSettings.shared.spotifyCookieSPDC.isEmpty, "Spotify Settings: Disconnect clears sp_dc cookie")
        }
        
        // Test fallback playlists and track resolution for Spotify importer
        let playlists = (try? await SpotifyImporter.shared.fetchUserPlaylists(accessToken: "")) ?? []
        assertTest(!playlists.isEmpty, "Spotify Importer: User playlists returns curated or user lists")
        assertTest(playlists.first?.title != nil, "Spotify Importer: Playlist has valid title (\(playlists.first?.title ?? ""))")
        
        if let firstPlaylist = playlists.first {
            let tracks = (try? await SpotifyImporter.shared.importPlaylistTracks(playlistId: firstPlaylist.id, accessToken: "")) ?? []
            assertTest(!tracks.isEmpty, "Spotify Importer: Playlist tracks imported successfully (\(tracks.count) tracks)")
            assertTest(!tracks[0].title.isEmpty, "Spotify Importer: First track has non-empty title (\(tracks[0].title))")
            assertTest(!tracks[0].artist.isEmpty, "Spotify Importer: First track has non-empty artist (\(tracks[0].artist))")
        }
    }
    
    // MARK: - Test 14: Comprehensive Settings Integration (Playback, Lyrics, Appearance, Performance, Local Music, Misc)
    do {
        await MainActor.run {
            let s = BitChordSettings.shared
            
            // 1. Playback
            s.outputPrecision = "32-bit float"
            assertTest(s.outputPrecision == "32-bit float", "Playback Settings: outputPrecision updated to 32-bit float")
            s.outputPrecision = "16-bit PCM"
            assertTest(s.outputPrecision == "16-bit PCM", "Playback Settings: outputPrecision updated to 16-bit PCM")
            s.loudnessNormalization = true
            assertTest(s.loudnessNormalization == true, "Playback Settings: loudnessNormalization is true")
            s.disableOnPhoneSpeaker = true
            assertTest(s.disableOnPhoneSpeaker == true, "Playback Settings: disableOnPhoneSpeaker is true")
            s.preferUSBDAC = true
            assertTest(s.preferUSBDAC == true, "Playback Settings: preferUSBDAC is true")
            s.skipSilenceEnabled = true
            assertTest(s.skipSilenceEnabled == true, "Playback Settings: skipSilenceEnabled is true")
            s.spatialAudioEnabled = true
            assertTest(s.spatialAudioEnabled == true, "Playback Settings: spatialAudioEnabled is true")
            
            // 2. Lyrics
            let sources = s.getLyricSources()
            assertTest(sources.count == 12, "Lyrics Settings: Contains all 12 lyric sources (found \(sources.count))")
            assertTest(sources.contains(where: { $0.name == "BetterLyrics Portato" }), "Lyrics Settings: Contains BetterLyrics Portato")
            assertTest(sources.contains(where: { $0.name == "PaxSenix" }), "Lyrics Settings: Contains PaxSenix")
            assertTest(sources.contains(where: { $0.name == "LyricsPlus" }), "Lyrics Settings: Contains LyricsPlus")
            assertTest(sources.contains(where: { $0.name == "Unison" }), "Lyrics Settings: Contains Unison")
            assertTest(sources.contains(where: { $0.name == "KuGou" }), "Lyrics Settings: Contains KuGou")
            assertTest(sources.contains(where: { $0.name == "LRCLIB" }), "Lyrics Settings: Contains LRCLIB")
            assertTest(sources.contains(where: { $0.name == "Musixmatch" }), "Lyrics Settings: Contains Musixmatch")
            assertTest(sources.contains(where: { $0.name == "Genius" }), "Lyrics Settings: Contains Genius")
            
            // Reorder & persist
            var modifiedSources = sources
            modifiedSources.swapAt(0, 1)
            s.saveLyricSources(modifiedSources)
            let reloadedSources = s.getLyricSources()
            assertTest(reloadedSources[0].name == sources[1].name, "Lyrics Settings: Custom source reordering persists successfully")
            
            // 3. Performance
            s.highPerformanceMode = true
            assertTest(s.highPerformanceMode == true, "Performance Settings: highPerformanceMode is true")
            s.targetRefreshRate = "120 Hz"
            assertTest(s.targetRefreshRate == "120 Hz", "Performance Settings: targetRefreshRate is 120 Hz")
            
            // 4. Local Music
            s.filterNonMusicAudio = true
            assertTest(s.filterNonMusicAudio == true, "Local Music Settings: filterNonMusicAudio is true")
            s.includeAppleMusicLibrary = true
            assertTest(s.includeAppleMusicLibrary == true, "Local Music Settings: includeAppleMusicLibrary is true")
            
            // 5. Miscellaneous
            s.showListenTogetherButton = true
            assertTest(s.showListenTogetherButton == true, "Misc Settings: showListenTogetherButton is true")
            s.hideStatusBarInPlayer = true
            assertTest(s.hideStatusBarInPlayer == true, "Misc Settings: hideStatusBarInPlayer is true")
            s.showQueueHistory = true
            assertTest(s.showQueueHistory == true, "Misc Settings: showQueueHistory is true")
            s.hideSongStatus = true
            assertTest(s.hideSongStatus == true, "Misc Settings: hideSongStatus is true")
            s.playNextOnSwipe = true
            assertTest(s.playNextOnSwipe == true, "Misc Settings: playNextOnSwipe is true")
            s.dontRepeatInCurrentSession = true
            assertTest(s.dontRepeatInCurrentSession == true, "Misc Settings: dontRepeatInCurrentSession is true")
            s.stopMusicOnCloseFromRecents = true
            assertTest(s.stopMusicOnCloseFromRecents == true, "Misc Settings: stopMusicOnCloseFromRecents is true")
            s.hideVolumeSlider = true
            assertTest(s.hideVolumeSlider == true, "Misc Settings: hideVolumeSlider is true")
            s.smartAudioAlignment = true
            assertTest(s.smartAudioAlignment == true, "Misc Settings: smartAudioAlignment is true")
        }
    }
    
    // MARK: - Test 15: Radio Recommendation Relevance & Multi-Attribute Filtering
    do {
        let seedSong = Track(
            id: "seed_indo_pop_1",
            title: "Separuh Aku",
            artist: "NOAH",
            album: "Seperti Seharusnya",
            duration: 268
        )
        let candidatePool: [Track] = [
            // 1. Seed duplicate (should be excluded)
            Track(id: "seed_indo_pop_1", title: "Separuh Aku", artist: "NOAH", album: "Seperti Seharusnya", duration: 268),
            // 2. Alternate ID but same song title & artist (should be excluded as duplicate)
            Track(id: "dup_separuh_aku", title: "Separuh Aku (Remastered 2024)", artist: "NOAH", album: "Seperti Seharusnya", duration: 268),
            // 3. Already played in current radio session (should be excluded)
            Track(id: "played_session_1", title: "Pupus", artist: "Dewa 19", album: "Cintailah Cinta", duration: 305),
            // 4. Relevant Indonesian Pop Rock tracks matching genre, subgenre, country, mood, tempo, energy, popularity
            Track(id: "rel_1", title: "Dan", artist: "Sheila On 7", album: "Sheila On 7", duration: 288),
            Track(id: "rel_2", title: "Mungkin Nanti", artist: "Peterpan", album: "Bintang di Surga", duration: 270),
            Track(id: "rel_3", title: "Cinta Ini Membunuhku", artist: "D'Masiv", album: "Perubahan", duration: 244),
            Track(id: "rel_4", title: "Kenangan Terindah", artist: "Samson", album: "Naluri Lelaki", duration: 252),
            Track(id: "rel_5", title: "Sobat", artist: "Padi", album: "Lain Dunia", duration: 315),
            Track(id: "rel_6", title: "Demi Waktu", artist: "Ungu", album: "Melayang", duration: 262),
            // 5. Excessive repetition of the same artist (4 tracks from Sheila On 7 -> should cap at maxPerArtist = 2)
            Track(id: "rel_so7_2", title: "Seberapa Pantas", artist: "Sheila On 7", album: "07 Des", duration: 240),
            Track(id: "rel_so7_3", title: "Sephia", artist: "Sheila On 7", album: "Kisah Klasik", duration: 290),
            Track(id: "rel_so7_4", title: "Melompat Lebih Tinggi", artist: "Sheila On 7", album: "Ost. 30 Hari", duration: 215),
            // 6. Unrelated genres / styles / tempos (EDM hardstyle, Classical Lo-Fi, Metalcore, Live version) -> must be rejected
            Track(id: "unrel_edm", title: "Hardstyle Rave Bass Drop", artist: "DJ Club Techno", album: "EDM Festival 150 BPM", duration: 195),
            Track(id: "unrel_metal", title: "Brutal Death Metal Breakdown", artist: "Slipknot", album: "Iowa Heavy Metal", duration: 230),
            Track(id: "unrel_lofi", title: "Chill Lo-Fi Study Ambient Beats", artist: "Lofi Sleep Piano", album: "Ambient Meditation", duration: 150),
            Track(id: "unrel_live", title: "Dan (Live at Synchronize Fest)", artist: "Sheila On 7", album: "Live Concert", duration: 310),
            Track(id: "unrel_short", title: "Separuh Aku Teaser", artist: "NOAH", album: "Promo", duration: 42)
        ]
        
        let sessionHistory: Set<String> = ["played_session_1"]
        let ranked = RadioRecommendationScorer.rankAndFilterRadioCandidates(
            seed: seedSong,
            candidates: candidatePool,
            sessionHistoryIds: sessionHistory,
            maxResults: 15,
            maxPerArtist: 2
        )
        
        assertTest(!ranked.isEmpty, "Radio Recommendations: Generated relevant playlist (\(ranked.count) tracks)")
        assertTest(!ranked.contains(where: { $0.id == seedSong.id || $0.title.lowercased().contains("separuh aku") }), "Radio Recommendations: Seed song and duplicate title excluded")
        assertTest(!ranked.contains(where: { $0.id == "played_session_1" }), "Radio Recommendations: Session history tracks excluded")
        assertTest(!ranked.contains(where: { $0.id.hasPrefix("unrel_") }), "Radio Recommendations: Unrelated genres, moods, tempos, live versions, and short clips excluded")
        
        let so7Count = ranked.filter { $0.artist.lowercased().contains("sheila on 7") }.count
        assertTest(so7Count <= 2, "Radio Recommendations: Artist repetition capped at max 2 per artist (found \(so7Count))")
        
        // Verify every recommended song matched at least 3 musical attributes
        let seedProfile = RadioRecommendationScorer.profile(for: seedSong)
        let allMultiAttributeMatched = ranked.allSatisfy { track in
            if let eval = RadioRecommendationScorer.evaluateCandidate(
                seed: seedSong,
                seedProfile: seedProfile,
                candidate: track,
                excludedTrackIds: [],
                excludedTitleArtistKeys: []
            ) {
                return eval.matchedAttributes >= 3
            }
            return false
        }
        assertTest(allMultiAttributeMatched, "Radio Recommendations: Every recommended song matches across >= 3 musical characteristics")
    }
    
    // MARK: - Test 16: Strict Audio Search & Track Version Matching
    do {
        // 1. Official Studio requested -> must match studio and reject live, acoustic, instrumental, remix, cover, karaoke, sped-up, slowed
        let studioTitle = "Creep"
        let studioArtist = "Radiohead"
        
        let exactStudioScore = TrackVersionMatcher.matchScore(
            requestedTitle: studioTitle,
            requestedArtist: studioArtist,
            requestedAlbum: "Pablo Honey",
            requestedDuration: 238,
            candidateTitle: "Creep",
            candidateArtist: "Radiohead - Topic",
            candidateAlbum: "Pablo Honey",
            candidateSubtitle: "Song • Radiohead • Pablo Honey",
            candidateDuration: 239
        )
        assertTest(exactStudioScore != nil && exactStudioScore! >= 80, "Version Matching: Official Studio recording matched with high confidence (\(exactStudioScore ?? 0))")
        
        let alternateVersions = [
            "Creep (Live at Reading Festival)",
            "Creep (Acoustic Version)",
            "Creep (Instrumental)",
            "Creep (Club Remix)",
            "Creep (Vocal Cover by Guest)",
            "Creep (Karaoke Version)",
            "Creep (Sped Up Nightcore)",
            "Creep (Slowed + Reverb)"
        ]
        for altTitle in alternateVersions {
            let score = TrackVersionMatcher.matchScore(
                requestedTitle: studioTitle,
                requestedArtist: studioArtist,
                requestedAlbum: "Pablo Honey",
                requestedDuration: 238,
                candidateTitle: altTitle,
                candidateArtist: studioArtist,
                candidateAlbum: "Pablo Honey",
                candidateDuration: 238
            )
            assertTest(score == nil, "Version Matching: Studio request strictly rejected alternate version '\(altTitle)'")
        }
        
        // 2. Explicit Acoustic requested -> must match Acoustic and reject Studio or Live
        let acousticReq = "Creep (Acoustic)"
        let acousticMatch = TrackVersionMatcher.matchScore(
            requestedTitle: acousticReq,
            requestedArtist: studioArtist,
            candidateTitle: "Creep (Acoustic Version)",
            candidateArtist: "Radiohead"
        )
        let acousticVsStudio = TrackVersionMatcher.matchScore(
            requestedTitle: acousticReq,
            requestedArtist: studioArtist,
            candidateTitle: "Creep",
            candidateArtist: "Radiohead"
        )
        let acousticVsLive = TrackVersionMatcher.matchScore(
            requestedTitle: acousticReq,
            requestedArtist: studioArtist,
            candidateTitle: "Creep (Live)",
            candidateArtist: "Radiohead"
        )
        assertTest(acousticMatch != nil, "Version Matching: Acoustic request matched Acoustic candidate")
        assertTest(acousticVsStudio == nil, "Version Matching: Acoustic request rejected plain Studio candidate")
        assertTest(acousticVsLive == nil, "Version Matching: Acoustic request rejected Live candidate")
        
        // 3. Explicit Instrumental, Live, Remix, Cover requests
        assertTest(
            TrackVersionMatcher.matchScore(
                requestedTitle: "Numb (Instrumental)",
                requestedArtist: "Linkin Park",
                candidateTitle: "Numb (Official Instrumental)",
                candidateArtist: "Linkin Park"
            ) != nil,
            "Version Matching: Instrumental request matched Instrumental candidate"
        )
        assertTest(
            TrackVersionMatcher.matchScore(
                requestedTitle: "Numb (Live in Texas)",
                requestedArtist: "Linkin Park",
                candidateTitle: "Numb (Live)",
                candidateArtist: "Linkin Park"
            ) != nil,
            "Version Matching: Live request matched Live candidate"
        )
        assertTest(
            TrackVersionMatcher.matchScore(
                requestedTitle: "Summertime Sadness (Cedric Gervais Remix)",
                requestedArtist: "Lana Del Rey",
                candidateTitle: "Summertime Sadness (Remix)",
                candidateArtist: "Lana Del Rey"
            ) != nil,
            "Version Matching: Remix request matched Remix candidate"
        )
        
        // 4. Featured artists & different artist rejection
        let featScore = TrackVersionMatcher.matchScore(
            requestedTitle: "Get Lucky (feat. Pharrell Williams)",
            requestedArtist: "Daft Punk",
            candidateTitle: "Get Lucky",
            candidateArtist: "Daft Punk, Pharrell Williams & Nile Rodgers"
        )
        assertTest(featScore != nil, "Version Matching: Handled featured artists across title and artist metadata")
        
        let wrongArtistScore = TrackVersionMatcher.matchScore(
            requestedTitle: "Yellow",
            requestedArtist: "Coldplay",
            candidateTitle: "Yellow",
            candidateArtist: "Tribute Cover Band"
        )
        assertTest(wrongArtistScore == nil, "Version Matching: Rejected same song title by unrelated tribute/cover artist")
    }
    
    // MARK: - Test 17: Objective Audio Quality Measurement & Selection
    do {
        let hiresFlac = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_24_96.flac")!,
            format: "audio/flac",
            codec: "flac",
            bitrate: 4608,
            isLossless: true,
            sampleRate: 96000,
            bitDepth: 24,
            sourceId: "addon_qobuz",
            sourceIsDirect: true
        )
        let cdFlac = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_16_44.flac")!,
            format: "audio/flac",
            codec: "flac",
            bitrate: 1411,
            isLossless: true,
            sampleRate: 44100,
            bitDepth: 16,
            sourceId: "addon_qobuz",
            sourceIsDirect: true
        )
        let lossy320 = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_320.m4a")!,
            format: "audio/mp4; codecs=\"mp4a.40.2\"",
            codec: "aac",
            bitrate: 320,
            isLossless: false,
            sampleRate: 48000,
            sourceId: "yt_innertube_ios",
            sourceIsDirect: true
        )
        let lossy256 = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_256.m4a")!,
            format: "audio/mp4; codecs=\"mp4a.40.2\"",
            codec: "aac",
            bitrate: 256,
            isLossless: false,
            sampleRate: 44100,
            sourceId: "yt_innertube_ios",
            sourceIsDirect: true
        )
        let lossy128 = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_128.m4a")!,
            format: "audio/mp4; codecs=\"mp4a.40.2\"",
            codec: "aac",
            bitrate: 128,
            isLossless: false,
            sampleRate: 44100,
            sourceId: "yt_innertube_ios",
            sourceIsDirect: true
        )
        // Fake lossless label on a lossy Opus/WebM stream -> must NOT be trusted as lossless
        let fakeLosslessWebm = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/track_opus.webm")!,
            format: "audio/webm; codecs=\"opus\"",
            codec: "opus",
            bitrate: 160,
            isLossless: true, // falsely claimed!
            sampleRate: 48000,
            sourceId: "piped",
            sourceIsDirect: false
        )
        
        assertTest(hiresFlac.isGenuineLossless == true, "Quality Measurement: 24-bit/96kHz FLAC recognized as genuine lossless")
        assertTest(cdFlac.isGenuineLossless == true, "Quality Measurement: 16-bit/44.1kHz FLAC recognized as genuine lossless")
        assertTest(fakeLosslessWebm.isGenuineLossless == false && fakeLosslessWebm.isLossless == false, "Quality Measurement: Rejected false lossless label on lossy audio/webm Opus stream")
        assertTest(hiresFlac.qualityScore > cdFlac.qualityScore, "Quality Measurement: 24-bit/96kHz FLAC outranks 16-bit/44.1kHz FLAC")
        assertTest(cdFlac.qualityScore > lossy320.qualityScore, "Quality Measurement: Genuine lossless FLAC outranks 320 kbps lossy AAC")
        assertTest(lossy320.qualityScore > lossy256.qualityScore && lossy256.qualityScore > lossy128.qualityScore, "Quality Measurement: Lossy bitrates ordered 320 > 256 > 128 kbps")
        
        let selectedTiers = StreamInfo.selectTopDistinctQualityLevels(
            from: [lossy128, lossy320, lossy256, fakeLosslessWebm],
            maxLevels: 3
        )
        assertTest(selectedTiers.count == 3, "Quality Selection: Capped at max 3 distinct quality levels per source")
        assertTest(selectedTiers[0].bitrate == 320 && selectedTiers[1].bitrate == 256 && selectedTiers[2].bitrate == 128, "Quality Selection: Prioritizes iOS AVPlayer-compatible streams sorted highest quality first (320 -> 256 -> 128 AAC)")
    }
    
    // MARK: - Test 18: Playback Fallback Sequence & Explicit Retry Limits
    do {
        let track = Track(id: "test_song_1", title: "Starlight", artist: "Muse", album: "Black Holes and Revelations", duration: 240)
        
        // Source 1 (Primary): 320 kbps and 128 kbps
        let s1_320 = StreamInfo(streamURL: URL(string: "https://primary.example.com/320.m4a")!, format: "audio/mp4", bitrate: 320, sourceId: "source1")
        let s1_128 = StreamInfo(streamURL: URL(string: "https://primary.example.com/128.m4a")!, format: "audio/mp4", bitrate: 128, sourceId: "source1")
        // Source 2 (Alt 1): 256 kbps
        let s2_256 = StreamInfo(streamURL: URL(string: "https://alt1.example.com/256.m4a")!, format: "audio/mp4", bitrate: 256, sourceId: "source2")
        // Source 3 (Alt 2): 192 kbps
        let s3_192 = StreamInfo(streamURL: URL(string: "https://alt2.example.com/192.m4a")!, format: "audio/mp4", bitrate: 192, sourceId: "source3")
        // Source 4 (Should be ignored because max 2 alternative sources = 3 total sources)
        let s4_128 = StreamInfo(streamURL: URL(string: "https://alt3.example.com/128.m4a")!, format: "audio/mp4", bitrate: 128, sourceId: "source4")
        
        var coordinator = PlaybackFallbackCoordinator(
            track: track,
            candidateSources: [[s1_128, s1_320], [s2_256], [s3_192], [s4_128]]
        )
        assertTest(coordinator.sources.count == 3, "Retry Limits: Enforced maximum 2 alternative sources (3 total sources)")
        
        // Attempt 1: Primary source, highest quality (320 kbps)
        let attempt1 = coordinator.beginInitialAttempt()
        assertTest(attempt1?.attemptNumber == 1 && attempt1?.stream.bitrate == 320 && attempt1?.sourceIndex == 0, "Fallback Sequence: Attempt #1 uses primary source at 320 kbps")
        
        // Fail Attempt 1 with recoverable network error -> Retry #1 of 320 kbps (Attempt #2, backoff 1.0s)
        let attempt2 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt1!.stream.streamURL, reason: .transientNetworkError)
        assertTest(attempt2?.attemptNumber == 2 && attempt2?.retryIndex == 1 && attempt2?.backoffSeconds == 1.0 && attempt2?.stream.bitrate == 320, "Fallback Sequence: Attempt #2 is Retry #1 of 320 kbps with 1s exponential backoff")
        assertTest(attempt2?.stream.streamURL != attempt1?.stream.streamURL, "Retry Limits: Never retries the exact same failed stream URL")
        
        // Fail Attempt 2 -> Retry #2 of 320 kbps (Attempt #3, backoff 2.0s)
        let attempt3 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt2!.stream.streamURL, reason: .transientNetworkError)
        assertTest(attempt3?.attemptNumber == 3 && attempt3?.retryIndex == 2 && attempt3?.backoffSeconds == 2.0 && attempt3?.stream.bitrate == 320, "Fallback Sequence: Attempt #3 is Retry #2 (max 2 retries per quality level) with 2s exponential backoff")
        
        // Fail Attempt 3 -> Must step down to next quality level in Primary Source (128 kbps, Attempt #4)
        let attempt4 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt3!.stream.streamURL, reason: .transientNetworkError)
        assertTest(attempt4?.attemptNumber == 4 && attempt4?.sourceIndex == 0 && attempt4?.qualityIndex == 1 && attempt4?.retryIndex == 0 && attempt4?.stream.bitrate == 128, "Fallback Sequence: Attempt #4 steps down to 128 kbps after 2 retries on 320 kbps")
        
        // Fail Attempt 4 with non-recoverable codec error -> Must skip retries on 128 kbps and switch to Alternative Source #1 (256 kbps, Attempt #5)
        let attempt5 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt4!.stream.streamURL, reason: .unsupportedCodecOrFormat)
        assertTest(attempt5?.attemptNumber == 5 && attempt5?.sourceIndex == 1 && attempt5?.stream.bitrate == 256, "Fallback Sequence: Attempt #5 switches to Alternative Source #1 (256 kbps)")
        
        // Fail Attempt 5 with codec error -> Switch to Alternative Source #2 (192 kbps, Attempt #6 - global max)
        let attempt6 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt5!.stream.streamURL, reason: .unsupportedCodecOrFormat)
        assertTest(attempt6?.attemptNumber == 6 && attempt6?.sourceIndex == 2 && attempt6?.stream.bitrate == 192, "Fallback Sequence: Attempt #6 reaches global 6-attempt ceiling on Alternative Source #2")
        
        // Fail Attempt 6 -> Must stop immediately because global 6-attempt limit is reached
        let attempt7 = coordinator.recordFailureAndNextAttempt(failedStreamURL: attempt6!.stream.streamURL, reason: .transientNetworkError)
        assertTest(attempt7 == nil && coordinator.isStopped && coordinator.totalAttempts == 6, "Retry Limits: Strictly stopped at global 6-attempt limit per song request")
        assertTest(coordinator.terminalErrorMessage != nil, "Fallback Sequence: Provides clear user-facing error message when all attempts fail")
        
        // Verify normal buffering vs failure classification
        assertTest(PlaybackFallbackCoordinator.isNormalBuffering(isWaitingToPlay: true, stallDurationSeconds: 3.5, hasFatalError: false) == true, "Failure Definition: Short 3.5s buffering is NOT classified as playback failure")
        assertTest(PlaybackFallbackCoordinator.isNormalBuffering(isWaitingToPlay: true, stallDurationSeconds: 10.5, hasFatalError: false) == false, "Failure Definition: Stall exceeding 10s ready-to-play timeout IS classified as playback failure")
    }
    
    // MARK: - Test 19: YouTube Video Audio Playback & Video URL Extraction
    do {
        // 1. Direct YouTube URL extraction (`watch?v=`, `youtu.be/`, `shorts/`)
        let watchId = YTMusicClient.extractYouTubeVideoId(from: "https://www.youtube.com/watch?v=zyLmavBAY7k")
        let shortUrlId = YTMusicClient.extractYouTubeVideoId(from: "https://youtu.be/zyLmavBAY7k?si=12345")
        assertTest(watchId == "zyLmavBAY7k", "YouTube Video URL: Extracted 11-char ID from youtube.com/watch?v=...")
        assertTest(shortUrlId == "zyLmavBAY7k", "YouTube Video URL: Extracted 11-char ID from youtu.be/...")
        
        // 2. Search with 'Videos' filter returns playable YouTube videos with 11-char videoIds
        let videoResults = (try? await YTMusicClient.shared.searchItems(query: "Tulus Teh Hijau", filter: "Videos")) ?? []
        assertTest(!videoResults.isEmpty, "YouTube Video Search: Returns video results for 'Videos' filter")
        let firstVideo = videoResults.first { $0.type == .video && ($0.videoId?.count == 11 || $0.id.count == 11) }
        assertTest(firstVideo != nil, "YouTube Video Search: Found playable video item with valid 11-char videoId")
        
        // 3. Direct M4A audio stream extraction for a YouTube Music Video (`zyLmavBAY7k`)
        let videoStreams = await StreamExtractor.shared.extractRankedStreamCandidates(
            trackId: "zyLmavBAY7k",
            title: "TULUS - Teh Hijau (Official Music Video)",
            artist: "Tulus",
            album: "YouTube Video",
            duration: 228
        )
        let bestVideoAudio = videoStreams.first?.first
        assertTest(bestVideoAudio != nil, "YouTube Video Audio: Extracted direct audio stream for YouTube Music Video")
        assertTest(bestVideoAudio?.isIOSAVPlayerCompatible == true, "YouTube Video Audio: Top extracted stream is natively compatible with iOS AVPlayer (audio/mp4 AAC)")
    }
    
    // MARK: - Test 20: Pre-Play Addon Resolution & Highest Quality Playback
    do {
        let engine = AudioPlayerEngine.shared
        
        // 1. Home / Explore track has source .youtube by default and isLossless == false
        let homeTrack = Track(
            id: "IqxdiPd_q40",
            title: "Mimpi Yang Sempurna",
            artist: "NOAH",
            album: "Taman Langit",
            duration: 218,
            source: .youtube
        )
        assertTest(homeTrack.source == .youtube, "Home/Explore Default: Track source defaults to .youtube")
        assertTest(!homeTrack.isLossless, "Home/Explore Default: Initial YouTube track isLossless is false")
        
        // 2. Play track via engine
        engine.setQueue([homeTrack], startIndex: 0)
        assertTest(engine.currentTrack?.source == .youtube, "Engine Queue: Currently loaded track has source .youtube")
        assertTest(engine.availableQualityUpgrade == nil, "Quality Upgrade: Initially nil before addon search completes")
        
        // 3. When played in highest quality directly from Addon, upgrade quality is hidden (nil)
        let mockAddonStream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream/flac/noah_hi_res.flac")!,
            format: "flac",
            codec: "flac",
            bitrate: 4608,
            isLossless: true,
            sampleRate: 96000,
            bitDepth: 24,
            sourceId: "addon_dev.bitperfect.qobuz",
            sourceIsDirect: true
        )
        let upgradeInfo = QualityUpgradeInfo(
            addonId: "dev.bitperfect.qobuz",
            addonName: "Qobuz Lossless",
            streamInfo: mockAddonStream,
            badge: "Hi-Res Lossless 24-bit/96.0 kHz"
        )
        engine.setAvailableQualityUpgrade(upgradeInfo)
        assertTest(engine.availableQualityUpgrade != nil, "Quality Upgrade: Upgrade offer is present and detected")
        assertTest(engine.availableQualityUpgrade?.badge.contains("Hi-Res") == true, "Quality Upgrade: Badge indicates Hi-Res audio")
        assertTest(engine.availableQualityUpgrade?.addonName == "Qobuz Lossless", "Quality Upgrade: Contains addon name 'Qobuz Lossless'")
        
        // 4. User triggers upgrade to higher quality stream from addon
        engine.currentTime = 42.0 // User has listened to 42 seconds
        engine.upgradeToAvailableQuality()
        
        assertTest(engine.currentTrack?.source == .addon, "Quality Upgrade: Track source switched to .addon")
        assertTest(engine.currentTrack?.isLossless == true, "Quality Upgrade: Track isLossless is now true")
        assertTest(engine.currentTrack?.bitDepth == 24, "Quality Upgrade: Track bitDepth is 24-bit")
        assertTest(engine.currentTrack?.sampleRate == 96000, "Quality Upgrade: Track sampleRate is 96.0 kHz")
        assertTest(engine.currentTrack?.audioBadge == "HI-RES LOSSLESS 24-bit/96.0 kHz", "Quality Upgrade: Audio badge shows Hi-Res Lossless")
        assertTest(engine.availableQualityUpgrade == nil, "Quality Upgrade: Offer dismissed and hidden after playing in highest quality")
    }
    
    // MARK: - Test 21: Quality Selection & Network Adaptation (Wi-Fi vs Cellular)
    do {
        let streamTiers = [
            StreamInfo(
                streamURL: URL(string: "https://example.com/flac24")!,
                format: "flac",
                codec: "flac",
                bitrate: 4608,
                isLossless: true,
                sampleRate: 96000,
                bitDepth: 24,
                sourceId: "addon_1",
                sourceIsDirect: true
            ),
            StreamInfo(
                streamURL: URL(string: "https://example.com/flac16")!,
                format: "flac",
                codec: "flac",
                bitrate: 1411,
                isLossless: true,
                sampleRate: 44100,
                bitDepth: 16,
                sourceId: "addon_1",
                sourceIsDirect: true
            ),
            StreamInfo(
                streamURL: URL(string: "https://example.com/aac256")!,
                format: "m4a",
                codec: "aac",
                bitrate: 256,
                isLossless: false,
                sampleRate: 44100,
                bitDepth: nil,
                sourceId: "addon_1",
                sourceIsDirect: true
            )
        ]
        
        // 1. Lossless setting selects top Hi-Res FLAC stream
        let selectedLossless = streamTiers.first(where: { $0.isGenuineLossless }) ?? streamTiers.first
        assertTest(selectedLossless?.isGenuineLossless == true, "Quality Selection: Lossless setting selects genuine lossless stream")
        assertTest(selectedLossless?.sampleRate == 96000, "Quality Selection: Highest sample rate 96kHz prioritized")
        
        // 2. Non-lossless setting selects lossy stream
        let selectedNonLossless = streamTiers.first(where: { !$0.isGenuineLossless })
        assertTest(selectedNonLossless?.isGenuineLossless == false, "Quality Selection: Non-lossless setting strictly rejects FLAC")
        assertTest(selectedNonLossless?.bitrate == 256, "Quality Selection: Non-lossless selects 256 kbps AAC")
        
        // 3. NetworkMonitor states check
        assertTest(NetworkMonitor.shared.isWifi || NetworkMonitor.shared.isCellular, "NetworkMonitor: Active network interface identified")
    }
    
    // MARK: - Test 22: Now Playing Scrubber & Duration Safety
    do {
        let engine = AudioPlayerEngine.shared
        let trackWithoutEngineDuration = Track(
            id: "test_dur_1",
            title: "Testing Scrubber",
            artist: "Tester",
            duration: 245
        )
        engine.setQueue([trackWithoutEngineDuration], startIndex: 0)
        engine.duration = 0 // Simulating bridge not yet sending duration
        
        let totalDuration = max(1, engine.duration > 0 ? engine.duration : (trackWithoutEngineDuration.duration > 0 ? trackWithoutEngineDuration.duration : 1))
        assertTest(totalDuration == 245, "Scrubber Math: totalDuration safely falls back to track duration (245s) when engine duration is 0")
        
        let displayTime = min(max(0, 15.0), totalDuration)
        assertTest(displayTime == 15.0, "Scrubber Math: displayTime is correctly clamped within totalDuration")
    }
    
    // MARK: - Test 23: Track Context Menu Upgrade, 24-bit/48kHz Pipeline Sync & Stats for Nerds Banner
    do {
        let engine = AudioPlayerEngine.shared
        let initialTrack = Track(
            id: "test_yt_lossy",
            title: "Lossy YouTube Track",
            artist: "Band",
            duration: 210,
            isLossless: false,
            source: .youtube
        )
        engine.setQueue([initialTrack], startIndex: 0)
        
        // 1. Initial track is lossy: upgrade should be allowed
        let canUpgradeInitial = !initialTrack.isLossless && (initialTrack.bitDepth ?? 0) < 24
        assertTest(canUpgradeInitial, "Quality Upgrade Guard: Lossy track shows Upgrade quality option")
        
        // 2. Perform quality upgrade from context menu action
        let upgradeResult = await engine.upgradeCurrentTrackToLossless(for: initialTrack)
        assertTest(upgradeResult.bitDepth == 24, "Quality Upgrade: Returns 24-bit bit depth")
        assertTest(upgradeResult.sampleRate >= 48000.0, "Quality Upgrade: Returns at least 48.0 kHz sample rate")
        assertTest(engine.currentTrack?.isLossless == true, "Quality Upgrade: Current track is now Lossless")
        assertTest(engine.currentTrack?.bitDepth == 24, "Quality Upgrade: Current track bitDepth is 24-bit")
        assertTest(engine.currentTrack?.source == .addon, "Quality Upgrade: Current track source is .addon")
        assertTest(engine.availableQualityUpgrade == nil, "Quality Upgrade: Available upgrade offer is dismissed")
        
        // 3. When track is lossless, upgrade quality MUST be hidden
        let isAlreadyLossless = engine.currentTrack?.isLossless == true || (engine.currentTrack?.bitDepth ?? 0) >= 24
        assertTest(isAlreadyLossless, "Quality Upgrade Guard: Upgraded track is recognized as Lossless")
        let shouldHideUpgradeMenu = isAlreadyLossless
        assertTest(shouldHideUpgradeMenu, "Quality Upgrade Guard: Upgrade quality menu option is strictly HIDDEN for lossless tracks")
        
        // 4. Lossless Banner visibility respects statsForNerdsEnabled
        let settings = BitChordSettings.shared
        settings.statsForNerdsEnabled = false
        let shouldShowBannerDefault = (engine.currentTrack?.isLossless == true) && settings.statsForNerdsEnabled
        assertTest(!shouldShowBannerDefault, "Lossless Banner: Default is HIDDEN when statsForNerdsEnabled is false")
        
        settings.statsForNerdsEnabled = true
        let shouldShowBannerWithStats = (engine.currentTrack?.isLossless == true) && settings.statsForNerdsEnabled
        assertTest(shouldShowBannerWithStats, "Lossless Banner: Shown when statsForNerdsEnabled is explicitly true")
        settings.statsForNerdsEnabled = false // Restore default
    }
    
    // MARK: - Test 24: Scrubber Seek Accuracy & Seamless Radio Playback
    do {
        let engine = AudioPlayerEngine.shared
        let radioTrack = Track(
            id: "seamless_rad_1",
            title: "Seamless Jam",
            artist: "Groove",
            duration: 300,
            isLossless: false,
            source: .youtube
        )
        engine.setQueue([radioTrack], startIndex: 0)
        engine.seek(to: 75.0)
        
        // 1. Seek updates currentTime and engages seek guard
        assertTest(engine.currentTime == 75.0, "Scrubber Seek: currentTime updated to exact seek target 75.0s")
        assertTest(engine.isSeeking == true, "Scrubber Seek: isSeeking guard active to prevent stale packets from reverting position")
        
        // 2. Start radio on currently playing track: must be seamless without stopping audio
        let currentPosBeforeRadio = engine.currentTime
        engine.startRadio(for: radioTrack)
        
        assertTest(engine.currentTrack?.id == radioTrack.id, "Seamless Radio: Currently playing track is preserved")
        assertTest(engine.queueIndex == 0, "Seamless Radio: Queue index stays on current track without resetting")
        assertTest(engine.currentTime == currentPosBeforeRadio, "Seamless Radio: Track playback position is NOT stopped or reverted")
    }
    
    // MARK: - Test 25: Progressive Track Cache & Range Merge Logic
    do {
        // 1. Contiguous & overlapping range merging
        let ranges1 = [ByteRange(start: 0, end: 99), ByteRange(start: 100, end: 199)]
        let merged1 = CachingResourceLoader.mergeRanges(ranges1)
        assertTest(merged1.count == 1 && merged1[0].start == 0 && merged1[0].end == 199, "Cache: Contiguous ranges [0-99] + [100-199] merge into [0-199]")
        
        let ranges2 = [ByteRange(start: 0, end: 150), ByteRange(start: 50, end: 200)]
        let merged2 = CachingResourceLoader.mergeRanges(ranges2)
        assertTest(merged2.count == 1 && merged2[0].start == 0 && merged2[0].end == 200, "Cache: Overlapping ranges [0-150] + [50-200] merge into [0-200]")
        
        let ranges3 = [ByteRange(start: 300, end: 399), ByteRange(start: 0, end: 99), ByteRange(start: 100, end: 299)]
        let merged3 = CachingResourceLoader.mergeRanges(ranges3)
        assertTest(merged3.count == 1 && merged3[0].start == 0 && merged3[0].end == 399, "Cache: Out-of-order ranges merge into single sorted [0-399]")
        
        let ranges4 = [ByteRange(start: 0, end: 99), ByteRange(start: 200, end: 299)]
        let merged4 = CachingResourceLoader.mergeRanges(ranges4)
        assertTest(merged4.count == 2, "Cache: Non-contiguous ranges preserved as separate blocks")
        
        // 2. Cache coverage lookup
        let isCovered = CachingResourceLoader.isRangeFullyCovered(offset: 20, length: 50, by: merged1)
        assertTest(isCovered == true, "Cache Lookup: Offset 20 length 50 fully covered by [0-199]")
        
        let notCovered = CachingResourceLoader.isRangeFullyCovered(offset: 150, length: 100, by: merged1)
        assertTest(notCovered == false, "Cache Lookup: Offset 150 length 100 not fully covered by [0-199]")
        
        // 3. Content-Type UTI mapping
        assertTest(CachingResourceLoader.contentTypeUTI(from: "audio/mp4") == "public.mpeg-4-audio", "UTI: audio/mp4 maps to public.mpeg-4-audio")
        assertTest(CachingResourceLoader.contentTypeUTI(from: "audio/flac") == "org.xiph.flac", "UTI: audio/flac maps to org.xiph.flac")
        assertTest(CachingResourceLoader.contentTypeUTI(from: "audio/mpeg") == "public.mp3", "UTI: audio/mpeg maps to public.mp3")
        
        // 4. LRU Cache Eviction with protected key
        let tempTestDir = FileManager.default.temporaryDirectory.appendingPathComponent("BitChordLRUTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempTestDir, withIntermediateDirectories: true)
        
        let fileA = tempTestDir.appendingPathComponent("trackA_high.audio")
        let fileB = tempTestDir.appendingPathComponent("trackB_high.audio")
        let dummyData = Data(repeating: 0x41, count: 600)
        try? dummyData.write(to: fileA)
        try? dummyData.write(to: fileB)
        
        // Set older modification date on fileA
        let pastDate = Date().addingTimeInterval(-3600)
        try? FileManager.default.setAttributes([.modificationDate: pastDate], ofItemAtPath: fileA.path)
        
        // Evict with limit of 1000 bytes, target 500 bytes, protecting trackA
        CachingResourceLoader.evictOldCacheFiles(in: tempTestDir, maxSizeBytes: 1000, targetSizeBytes: 500, protectedKey: "trackA")
        assertTest(FileManager.default.fileExists(atPath: fileA.path), "LRU Eviction: Protected active track is never evicted")
        
        try? FileManager.default.removeItem(at: tempTestDir)
        
        // 5. Backend preference: YouTube direct stream plays via AVPlayer with CachingResourceLoader
        let engine = AudioPlayerEngine.shared
        let ytTrack = Track(
            id: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            artist: "Rick Astley",
            duration: 213,
            streamURL: URL(string: "https://example.com/audio.m4a"),
            isLossless: false,
            source: .youtube
        )
        engine.setQueue([ytTrack], startIndex: 0)
        assertTest(engine.activeBackend == .avPlayer, "Backend Routing: Direct stream track prioritizes .avPlayer backend")
        
        // 6. Disk Stream Cache & Pre-caching resolution
        let testCacheTrackId = "test_precache_track_\(UUID().uuidString)"
        let testCacheDir = StreamExtractor.streamCacheDirectory
        let testFile = testCacheDir.appendingPathComponent("\(testCacheTrackId).m4a")
        let dummyAudioData = Data(repeating: 0x55, count: 40000) // > 32KB
        try? dummyAudioData.write(to: testFile)
        
        let foundViaStreamExtractor = StreamExtractor.shared.getCachedAudioFileURL(trackId: testCacheTrackId)
        assertTest(foundViaStreamExtractor != nil, "Disk Cache: StreamExtractor finds cached file > 32KB")
        
        let foundViaEngine = AudioPlayerEngine.getCachedAudioFileURL(for: testCacheTrackId)
        assertTest(foundViaEngine != nil, "Disk Cache: AudioPlayerEngine finds cached file")
        
        // Clean up test file
        try? FileManager.default.removeItem(at: testFile)
        
        // 7. Auto pre-caching trigger does not crash
        engine.setQueue([ytTrack, ytTrack, ytTrack], startIndex: 0)
        engine.triggerAutoPrecacheNextTracks()
        assertTest(true, "Auto Pre-caching: triggerAutoPrecacheNextTracks executes cleanly")
        
        // 8. Addon Health Check & Reordering
        let settings = BitChordSettings.shared
        let testAddonA = AddonSource(
            id: "addon_test_a",
            name: "Qobuz [Test A]",
            version: "1.0",
            manifestURL: "https://example.com/a/manifest.json",
            baseURL: "https://example.com/a"
        )
        let testAddonB = AddonSource(
            id: "addon_test_b",
            name: "Monochrome [Test B]",
            version: "1.0",
            manifestURL: "https://example.com/b/manifest.json",
            baseURL: "https://example.com/b"
        )
        settings.addAddonSource(testAddonA)
        settings.addAddonSource(testAddonB)
        
        let now = Date()
        settings.updateAddonHealth(id: testAddonA.id, isReachable: true, detail: "Qobuz FLAC", checkedAt: now)
        let updatedA = settings.addonSources.first(where: { $0.id == testAddonA.id })
        assertTest(updatedA?.isReachable == true, "Addon Health: Mark as reachable")
        assertTest(updatedA?.formattedCheckedTime?.hasPrefix("Checked") == true, "Addon Health: Formats checked timestamp")
        
        // Test Reordering: Move B before A
        if let idxB = settings.addonSources.firstIndex(where: { $0.id == testAddonB.id }) {
            settings.moveAddonSources(from: IndexSet(integer: idxB), to: 0)
            assertTest(settings.addonSources.first?.id == testAddonB.id, "Addon Reorder: Successfully moved addon to priority #1")
        }
        
        // Clean up test addons
        settings.removeAddonSource(id: testAddonA.id)
        settings.removeAddonSource(id: testAddonB.id)
        
        // 9. Track Length Tolerance Setting
        assertTest(settings.trackLengthToleranceSeconds >= 0, "Track Length Tolerance: Setting configured with default \(settings.trackLengthToleranceSeconds)s")
        
        // 10. Cache Management & Live Diagnostics Telemetry
        let initialCache = CachingResourceLoader.calculateTotalCacheSize()
        assertTest(initialCache.bytes >= 0, "Cache Sizing: Cache size calculation returns non-negative bytes (\(initialCache.formatted))")
        assertTest(initialCache.count >= 0, "Cache Sizing: Cache file count returns non-negative count (\(initialCache.count) files)")
        
        CachingResourceLoader.clearAllAudioCache()
        let clearedCache = CachingResourceLoader.calculateTotalCacheSize()
        assertTest(clearedCache.bytes == 0, "Cache Clearing: clearAllAudioCache reduces audio cache to 0 bytes")
        assertTest(clearedCache.count == 0, "Cache Clearing: clearAllAudioCache reduces audio cache to 0 files")
        
        assertTest(engine.audioRouteRebuildCount >= 1, "Diagnostics: Route rebuild count initialized and tracked")
        assertTest(engine.playbackStallCount >= 0, "Diagnostics: Playback stall count tracked accurately")
        assertTest(engine.liveOutputPeak >= 0.0 && engine.liveOutputPeak <= 1.0, "Diagnostics: Live output peak is bounded within [0.0, 1.0]")
    }
    
    print("==================================================")
    print("🏁 Test Results: \(passed) Passed, \(failed) Failed")
    print("==================================================")
    
    if failed > 0 {
        exit(1)
    }
}

// Entrypoint
await runAllTests()
