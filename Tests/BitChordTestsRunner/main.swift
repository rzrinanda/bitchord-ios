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
        assertTest(track3.album == "YouTube Music", "Metadata Extraction: Video subtitle defaults album to 'YouTube Music' without false views")
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
    
    print("==================================================")
    print("🏁 Test Results: \(passed) Passed, \(failed) Failed")
    print("==================================================")
    
    if failed > 0 {
        exit(1)
    }
}

// Entrypoint
await runAllTests()
