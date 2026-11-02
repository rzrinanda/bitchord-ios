import Foundation
import BitChord

@MainActor
func runAllTests() async {
    print("==================================================")
    print("▶ Starting BitChord for iOS Test Suite")
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
    
    // MARK: - Test 1: LRC Parser Standard & Syllables
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
        assertTest(lyrics.isSynced == true, "LRCParser identifies synced lyrics")
        assertTest(lyrics.lines.count == 5, "LRCParser correctly handles multiple timestamps per line (expected 5, got \(lyrics.lines.count))")
        assertTest(lyrics.lines[0].timestamp == 15.3, "LRCParser calculates timestamp accurately (00:15.30 -> 15.3s)")
        assertTest(lyrics.lines[2].syllables.count == 4, "LRCParser extracts syllable timestamps (<mm:ss.xx>)")
        
        let activeIdx = lyrics.activeLineIndex(for: 16.0)
        assertTest(activeIdx == 0, "LRCParser active line lookup at 16.0s resolves to index 0")
        
        let activeIdx2 = lyrics.activeLineIndex(for: 25.0)
        assertTest(activeIdx2 == 2, "LRCParser active line lookup at 25.0s resolves to index 2")
    }
    
    // MARK: - Test 2: Lyrics Storage Switch (Auto-Download ON vs OFF)
    do {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BitChordTest_\(UUID().uuidString)")
        
        // --- Test 2A: Auto-Download ENABLED ---
        let storageOn = LyricsStorageManager(customStorageURL: tempDir, defaultAutoDownload: true)
        await storageOn.setAutoDownload(true)
        
        let testLyrics1 = Lyrics(
            trackId: "track_auto_download_on",
            isSynced: true,
            lines: [LyricLine(timestamp: 5.0, text: "Line 1")],
            plainLyrics: "Line 1",
            provider: "LRCLIB",
            source: .network
        )
        
        await storageOn.processRetrievedLyrics(lyrics: testLyrics1, rawLRC: "[00:05.00]Line 1")
        
        let isStoredOnDiskWhenOn = await storageOn.isLyricsStoredOnDisk(trackId: "track_auto_download_on")
        assertTest(isStoredOnDiskWhenOn == true, "Auto-Download ON: Lyrics are saved to local persistent storage")
        
        let retrievedFromDisk = await storageOn.getLyrics(for: "track_auto_download_on")
        assertTest(retrievedFromDisk?.trackId == "track_auto_download_on", "Stored lyrics can be retrieved from disk cache")
        assertTest(retrievedFromDisk?.source == .localDisk, "Retrieved lyrics source is updated to localDisk")
        
        // --- Test 2B: Auto-Download DISABLED ---
        let tempDirOff = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BitChordTestOff_\(UUID().uuidString)")
        let storageOff = LyricsStorageManager(customStorageURL: tempDirOff, defaultAutoDownload: false)
        await storageOff.setAutoDownload(false)
        
        let testLyrics2 = Lyrics(
            trackId: "track_auto_download_off",
            isSynced: true,
            lines: [LyricLine(timestamp: 10.0, text: "Streaming Line")],
            plainLyrics: "Streaming Line",
            provider: "LRCLIB",
            source: .network
        )
        
        await storageOff.processRetrievedLyrics(lyrics: testLyrics2, rawLRC: "[00:10.00]Streaming Line")
        
        let isStoredOnDiskWhenOff = await storageOff.isLyricsStoredOnDisk(trackId: "track_auto_download_off")
        assertTest(isStoredOnDiskWhenOff == false, "Auto-Download OFF: Lyrics are NOT saved to local persistent storage")
        
        // But in-memory retrieval works for current session:
        let sessionLyrics = await storageOff.getLyrics(for: "track_auto_download_off")
        assertTest(sessionLyrics != nil, "Auto-Download OFF: In-memory session lyrics are available without disk footprint")
        
        // --- Test 2C: Manual Download when Auto-Download is OFF ---
        await storageOff.manuallySaveToDisk(lyrics: testLyrics2, rawLRC: "[00:10.00]Streaming Line")
        let isNowSaved = await storageOff.isLyricsStoredOnDisk(trackId: "track_auto_download_off")
        assertTest(isNowSaved == true, "Manual Save: Explicitly saves lyrics to disk even when auto-download is disabled")
        
        // Clean up
        await storageOn.clearAllDiskStorage()
        await storageOff.clearAllDiskStorage()
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: tempDirOff)
    }
    
    // MARK: - Test 3: Playback Queue & Shuffle Engine
    do {
        let engine = AudioPlayerEngine.shared
        let track1 = Track(id: "1", title: "Song 1", artist: "Artist 1", duration: 180)
        let track2 = Track(id: "2", title: "Song 2", artist: "Artist 2", duration: 200)
        let track3 = Track(id: "3", title: "Song 3", artist: "Artist 3", duration: 220)
        
        engine.setQueue([track1, track2, track3], startIndex: 0)
        assertTest(engine.queue.count == 3, "Queue initialized with 3 tracks")
        assertTest(engine.currentTrack?.id == "1", "Current track is set to first track")
        
        engine.nextTrack()
        assertTest(engine.currentTrack?.id == "2", "nextTrack advances queue to second track")
        
        engine.insertNextInQueue(Track(id: "4", title: "Song 4", artist: "Artist 4", duration: 150))
        assertTest(engine.queue[engine.queueIndex + 1].id == "4", "insertNextInQueue correctly places track as next up")
        
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .all, "cycleRepeatMode toggles to .all")
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .one, "cycleRepeatMode toggles to .one")
        engine.cycleRepeatMode()
        assertTest(engine.repeatMode == .off, "cycleRepeatMode toggles back to .off")
    }
    
    // MARK: - Test 4: Audio Engine Helpers & Crossfade
    do {
        let crossfade = CrossfadeManager.shared
        let fadeOutVol = crossfade.fadeOutVolume(currentTime: 198.0, duration: 200.0, crossfadeDuration: 4.0)
        assertTest(fadeOutVol == 0.5, "CrossfadeManager computes 50% fade volume at midpoint (expected 0.5, got \(fadeOutVol))")
        
        let fadeInVol = crossfade.fadeInVolume(currentTime: 2.0, crossfadeDuration: 4.0)
        assertTest(fadeInVol == 0.5, "CrossfadeManager computes 50% fade-in volume at midpoint (expected 0.5, got \(fadeInVol))")
        
        let noFadeVol = crossfade.fadeOutVolume(currentTime: 50.0, duration: 200.0, crossfadeDuration: 4.0)
        assertTest(noFadeVol == 1.0, "CrossfadeManager leaves volume at 1.0 when outside crossfade window")
        
        let eqBass = EqualizerPreset.bassBoost
        assertTest(eqBass.gains.count == 10, "Equalizer preset has 10 frequency bands")
        assertTest(eqBass.gains[0] > eqBass.gains[5], "Bass boost preset elevates low frequencies")
    }
    
    // MARK: - Test 5: Track & Audio Quality Formatting
    do {
        let losslessTrack = Track(
            id: "hi_res_1",
            title: "Test Hi-Res",
            artist: "Test Artist",
            duration: 215,
            isLossless: true,
            sampleRate: 96000,
            bitDepth: 24
        )
        assertTest(losslessTrack.audioBadge == "HI-RES LOSSLESS 24-bit/96.0 kHz", "Hi-Res track audio badge formatting")
        assertTest(losslessTrack.formattedDuration == "3:35", "Track duration formatted as 3:35")
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
