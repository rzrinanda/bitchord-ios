import Foundation

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var artworkURL: URL?
    public var streamURL: URL?
    public var isLossless: Bool
    public var sampleRate: Double?
    public var bitDepth: Int?
    public var lyricsId: String?
    public var isExplicit: Bool
    
    public init(
        id: String,
        title: String,
        artist: String,
        album: String = "",
        duration: TimeInterval,
        artworkURL: URL? = nil,
        streamURL: URL? = nil,
        isLossless: Bool = false,
        sampleRate: Double? = nil,
        bitDepth: Int? = nil,
        lyricsId: String? = nil,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.streamURL = streamURL
        self.isLossless = isLossless
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.lyricsId = lyricsId
        self.isExplicit = isExplicit
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var audioBadge: String {
        if isLossless {
            if let rate = sampleRate, let depth = bitDepth, rate > 48000 {
                return String(format: "HI-RES LOSSLESS %d-bit/%.1f kHz", depth, rate / 1000.0)
            }
            return "LOSSLESS"
        }
        return "AAC"
    }
    
    /// Display badge formatted cleanly for Now Playing UI matching reference screenshots
    public var displayAudioQualityBadge: String {
        if isLossless {
            if (sampleRate ?? 0) > 48000 || (bitDepth ?? 0) > 16 {
                return "Hi-Res Lossless"
            }
            return "Lossless"
        }
        return "High Quality"
    }
}

// MARK: - 1. Strict Track Version Classification & Matching
public enum TrackVersionType: String, CaseIterable, Codable, Sendable {
    case studio = "Studio"
    case live = "Live"
    case acoustic = "Acoustic"
    case instrumental = "Instrumental"
    case remix = "Remix"
    case cover = "Cover"
    case karaoke = "Karaoke"
    case spedUp = "Sped Up"
    case slowed = "Slowed"
}

public struct TrackVersionMatcher: Sendable {
    public init() {}
    
    /// Detects the canonical version type of a track from its title and album/subtitle metadata.
    public static func detectVersion(title: String, album: String? = "", subtitle: String? = "") -> TrackVersionType {
        let combined = "\(title) \(album ?? "") \(subtitle ?? "")".lowercased()
        let titleLower = title.lowercased()
        
        // Check explicit version markers in priority order
        if containsWordOrPhrase(titleLower, patterns: ["karaoke", "backing track", "minus one"]) ||
           containsWordOrPhrase(combined, patterns: ["karaoke version", "karaoke"]) {
            return .karaoke
        }
        if containsWordOrPhrase(titleLower, patterns: ["sped up", "speed up", "nightcore"]) ||
           containsWordOrPhrase(combined, patterns: ["sped up", "nightcore"]) {
            return .spedUp
        }
        if containsWordOrPhrase(titleLower, patterns: ["slowed", "reverb", "chopped and screwed"]) ||
           containsWordOrPhrase(combined, patterns: ["slowed", "slowed + reverb", "slowed & reverb"]) {
            return .slowed
        }
        if containsWordOrPhrase(titleLower, patterns: ["instrumental", "inst.", "off vocal"]) ||
           containsWordOrPhrase(combined, patterns: ["instrumental version", "instrumental"]) {
            return .instrumental
        }
        if containsWordOrPhrase(titleLower, patterns: ["acoustic", "akustik", "unplugged", "stripped"]) ||
           containsWordOrPhrase(combined, patterns: ["acoustic version", "unplugged", "stripped"]) {
            return .acoustic
        }
        if containsWordOrPhrase(titleLower, patterns: ["remix", "bootleg", "vip mix", "club mix", "extended mix", "radio edit remix", "koplo", "jedag jedug", "dj "]) ||
           containsWordOrPhrase(combined, patterns: ["remix", "remixes"]) {
            return .remix
        }
        if containsWordOrPhrase(titleLower, patterns: ["cover", "covered by", "tribute to"]) ||
           containsWordOrPhrase(combined, patterns: ["cover version", "covered by"]) {
            return .cover
        }
        if containsWordOrPhrase(titleLower, patterns: ["live", "live at", "live from", "live in", "in concert", "konser", "tour", "session", "tiny desk"]) ||
           containsWordOrPhrase(combined, patterns: ["live at", "live from", "live in", "live version", "(live)", "[live]"]) {
            return .live
        }
        return .studio
    }
    
    private static func containsWordOrPhrase(_ text: String, patterns: [String]) -> Bool {
        for p in patterns {
            let escaped = NSRegularExpression.escapedPattern(for: p)
            let regex = "(?:^|[^a-z0-9])\(escaped)(?:$|[^a-z0-9])"
            if text.range(of: regex, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    /// Normalizes a song title by stripping version parentheticals, "Official Audio/Video" suffixes, and featured artist tags.
    public static func normalizeCoreTitle(_ rawTitle: String) -> String {
        var s = rawTitle.lowercased()
        // Remove bracketed or parenthetical metadata e.g. (Official Audio), [Live], (feat. X), etc.
        s = s.replacingOccurrences(of: #"\([^\)]*\)"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
        // Strip trailing "- live", "- acoustic", "- remastered", "ft. ...", "feat. ..."
        if let featRange = s.range(of: #"\b(feat\.?|ft\.?|featuring)\b.*"#, options: .regularExpression) {
            s.removeSubrange(featRange)
        }
        if let dashRange = s.range(of: #"\s+-\s+(live|acoustic|instrumental|remix|cover|karaoke|sped up|slowed|remaster(ed)?|official.*).*$"#, options: .regularExpression) {
            s.removeSubrange(dashRange)
        }
        s = s.replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
        let tokens = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return tokens.joined(separator: " ")
    }
    
    /// Extracts primary and featured artists normalized for comparison.
    public static func normalizeArtists(_ rawArtist: String) -> [String] {
        let lower = rawArtist.lowercased()
            .replacingOccurrences(of: " - topic", with: "")
            .replacingOccurrences(of: "vevo", with: "")
            .replacingOccurrences(of: "official", with: "")
        let parts = lower.components(separatedBy: CharacterSet(charactersIn: ",;&/"))
            .flatMap { $0.components(separatedBy: " feat.") }
            .flatMap { $0.components(separatedBy: " ft.") }
            .flatMap { $0.components(separatedBy: " featuring ") }
            .flatMap { $0.components(separatedBy: " x ") }
            .map {
                $0.replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty && $0 != "youtube music" && $0 != "various artists" }
        return parts
    }
    
    /// Strictly verifies whether a candidate track matches the requested track's title, artist, and exact version type.
    /// Returns nil if the version is mismatched (e.g., Live or Acoustic when Studio was requested) or if title/artist do not match.
    /// Returns a relevance score (0...100+) when valid.
    public static func matchScore(
        requestedTitle: String,
        requestedArtist: String?,
        requestedAlbum: String? = nil,
        requestedDuration: TimeInterval? = nil,
        candidateTitle: String,
        candidateArtist: String,
        candidateAlbum: String? = "",
        candidateSubtitle: String? = "",
        candidateDuration: TimeInterval? = nil
    ) -> Double? {
        let targetVersion = detectVersion(title: requestedTitle, album: requestedAlbum ?? "")
        let candidateVersion = detectVersion(title: candidateTitle, album: candidateAlbum ?? "", subtitle: candidateSubtitle ?? "")
        
        // Strict rule: Never substitute one version for another!
        guard targetVersion == candidateVersion else {
            return nil
        }
        
        // Reject short clips/teasers/previews (< 60s) when full song is requested
        if let cDur = candidateDuration, cDur > 0 && cDur < 60 {
            if (requestedDuration ?? 180) >= 60 {
                return nil
            }
        }
        
        let combinedCandidateLower = "\(candidateTitle) \(candidateSubtitle ?? "")".lowercased()
        if combinedCandidateLower.contains("teaser") || combinedCandidateLower.contains("#shorts") || combinedCandidateLower.contains("preview") || combinedCandidateLower.contains("30 sec") {
            return nil
        }
        
        // Title matching
        let reqCore = normalizeCoreTitle(requestedTitle)
        let candCore = normalizeCoreTitle(candidateTitle)
        guard !reqCore.isEmpty && !candCore.isEmpty else { return nil }
        
        var score: Double = 0
        if reqCore == candCore {
            score += 50.0
        } else {
            let reqTokens = Set(reqCore.split(separator: " ").map(String.init))
            let candTokens = Set(candCore.split(separator: " ").map(String.init))
            let intersection = reqTokens.intersection(candTokens)
            let recall = Double(intersection.count) / Double(max(1, reqTokens.count))
            let precision = Double(intersection.count) / Double(max(1, candTokens.count))
            if recall >= 0.8 && precision >= 0.6 {
                score += 35.0 * ((recall + precision) / 2.0)
            } else {
                return nil
            }
        }
        
        // Artist matching
        if let reqArtist = requestedArtist, !reqArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let reqArtists = normalizeArtists(reqArtist)
            let candArtists = normalizeArtists("\(candidateArtist) \(candidateSubtitle ?? "") \(candidateTitle)")
            
            if !reqArtists.isEmpty {
                var artistMatched = false
                for rArt in reqArtists {
                    if candArtists.contains(where: { $0 == rArt || $0.contains(rArt) || rArt.contains($0) }) {
                        artistMatched = true
                        score += 35.0
                        break
                    }
                }
                if !artistMatched {
                    // If candidate is a cover or by a completely different artist, reject!
                    return nil
                }
            }
        } else {
            score += 20.0
        }
        
        // Prioritize official studio recordings / Topic channels when studio version is selected
        if targetVersion == .studio {
            let lowerArt = candidateArtist.lowercased()
            let lowerTitle = candidateTitle.lowercased()
            if lowerArt.contains("- topic") || lowerTitle.contains("official audio") {
                score += 15.0
            } else if !lowerTitle.contains("music video") && !lowerTitle.contains("official video") {
                score += 8.0
            }
        }
        
        // Album affinity bonus
        if let reqAlb = requestedAlbum, !reqAlb.isEmpty, let candAlb = candidateAlbum, !candAlb.isEmpty {
            let rAlbNorm = normalizeCoreTitle(reqAlb)
            let cAlbNorm = normalizeCoreTitle(candAlb)
            if !rAlbNorm.isEmpty && (rAlbNorm == cAlbNorm || cAlbNorm.contains(rAlbNorm) || rAlbNorm.contains(cAlbNorm)) {
                score += 10.0
            }
        }
        
        // Duration proximity check (reject wildly different durations if known, e.g. > 90s difference on studio track)
        if let reqDur = requestedDuration, reqDur >= 60, let candDur = candidateDuration, candDur >= 60 {
            let diff = abs(reqDur - candDur)
            if diff <= 8 {
                score += 10.0
            } else if diff <= 25 {
                score += 4.0
            } else if diff > 90 && targetVersion == .studio {
                return nil
            }
        }
        
        return score
    }
}

// MARK: - 2. Multi-Factor Radio Recommendation Relevance Engine
public struct RadioTrackProfile: Sendable {
    public let genre: String
    public let subgenre: String
    public let countryOrigin: String
    public let mood: String
    public let tempoBPM: Int
    public let energyLevel: Double // 0.0 ... 1.0
    public let popularityTier: Double // 0.0 ... 1.0
    public let primaryArtist: String
    
    public init(
        genre: String,
        subgenre: String,
        countryOrigin: String,
        mood: String,
        tempoBPM: Int,
        energyLevel: Double,
        popularityTier: Double,
        primaryArtist: String
    ) {
        self.genre = genre
        self.subgenre = subgenre
        self.countryOrigin = countryOrigin
        self.mood = mood
        self.tempoBPM = tempoBPM
        self.energyLevel = energyLevel
        self.popularityTier = popularityTier
        self.primaryArtist = primaryArtist
    }
}

public struct RadioRecommendationScorer: Sendable {
    public init() {}
    
    /// Infers a rich musical profile for a track using artist/album/title metadata and curated musicology knowledge.
    public static func profile(for track: Track) -> RadioTrackProfile {
        let primaryArtist = TrackVersionMatcher.normalizeArtists(track.artist).first ?? track.artist.lowercased().trimmingCharacters(in: .whitespaces)
        let combined = "\(track.title) \(track.artist) \(track.album)".lowercased()
        
        // 1. Curated artist taxonomy (Genre, Subgenre, Country/Origin, Mood, Average BPM, Energy, Popularity)
        let knownProfiles: [String: (genre: String, subgenre: String, country: String, mood: String, bpm: Int, energy: Double, pop: Double)] = [
            "noah": ("pop rock", "indonesian pop rock", "ID", "melancholic", 118, 0.65, 0.95),
            "peterpan": ("pop rock", "indonesian pop rock", "ID", "melancholic", 120, 0.68, 0.95),
            "dewa 19": ("pop rock", "indonesian rock ballad", "ID", "romantic", 112, 0.64, 0.96),
            "sheila on 7": ("pop rock", "indonesian pop rock", "ID", "nostalgic", 122, 0.70, 0.94),
            "padi": ("pop rock", "indonesian alternative rock", "ID", "emotional", 116, 0.68, 0.90),
            "ungu": ("pop rock", "indonesian pop ballad", "ID", "romantic", 110, 0.60, 0.90),
            "d masiv": ("pop rock", "indonesian pop rock", "ID", "melancholic", 114, 0.62, 0.88),
            "kerispatih": ("pop", "indonesian pop ballad", "ID", "melancholic", 98, 0.52, 0.87),
            "ada band": ("pop", "indonesian pop ballad", "ID", "romantic", 102, 0.55, 0.88),
            "samson": ("pop rock", "indonesian pop ballad", "ID", "romantic", 106, 0.58, 0.85),
            "gigi": ("rock", "indonesian alternative rock", "ID", "energetic", 130, 0.78, 0.88),
            "slank": ("rock", "indonesian blues rock", "ID", "rebellious", 128, 0.76, 0.90),
            "ari lasso": ("pop rock", "indonesian pop ballad", "ID", "romantic", 108, 0.60, 0.89),
            "tulus": ("pop", "indonesian soul pop", "ID", "warm", 104, 0.54, 0.93),
            "jikustik": ("pop", "indonesian pop ballad", "ID", "nostalgic", 105, 0.55, 0.84),
            "the rain": ("pop rock", "indonesian indie pop", "ID", "nostalgic", 118, 0.65, 0.82),
            "muse": ("rock", "alternative rock", "UK", "anthemic", 128, 0.84, 0.94),
            "radiohead": ("rock", "alternative rock", "UK", "atmospheric", 118, 0.70, 0.94),
            "coldplay": ("rock", "alternative pop rock", "UK", "uplifting", 122, 0.74, 0.97),
            "the killers": ("rock", "indie rock", "US", "anthemic", 132, 0.85, 0.92),
            "arctic monkeys": ("rock", "indie rock", "UK", "groovy", 124, 0.78, 0.95),
            "placebo": ("rock", "alternative rock", "UK", "brooding", 126, 0.80, 0.85),
            "franz ferdinand": ("rock", "indie rock", "UK", "energetic", 130, 0.82, 0.86),
            "oasis": ("rock", "britpop", "UK", "anthemic", 118, 0.76, 0.94),
            "keane": ("rock", "piano rock", "UK", "emotional", 116, 0.68, 0.88),
            "snow patrol": ("rock", "alternative rock", "UK", "emotional", 114, 0.66, 0.87),
            "the fray": ("rock", "piano rock", "US", "emotional", 112, 0.64, 0.86),
            "onerepublic": ("pop rock", "pop rock", "US", "uplifting", 124, 0.76, 0.92),
            "imagine dragons": ("rock", "arena pop rock", "US", "anthemic", 128, 0.84, 0.94),
            "the script": ("pop rock", "celtic pop rock", "IE", "emotional", 116, 0.68, 0.88),
            "linkin park": ("rock", "alternative metal", "US", "intense", 135, 0.92, 0.96),
            "evanescence": ("rock", "gothic rock", "US", "dramatic", 128, 0.86, 0.90),
            "green day": ("rock", "punk rock", "US", "energetic", 142, 0.90, 0.93),
            "system of a down": ("rock", "alternative metal", "US", "intense", 140, 0.94, 0.91),
            "queen": ("rock", "classic rock", "UK", "anthemic", 122, 0.80, 0.97),
            "led zeppelin": ("rock", "classic hard rock", "UK", "powerful", 124, 0.82, 0.95),
            "pink floyd": ("rock", "progressive rock", "UK", "atmospheric", 108, 0.65, 0.95),
            "the beatles": ("rock", "classic pop rock", "UK", "melodic", 120, 0.72, 0.98),
            "nirvana": ("rock", "grunge", "US", "raw", 126, 0.86, 0.95),
            "the weeknd": ("pop", "synthwave r&b", "CA", "nocturnal", 118, 0.78, 0.98),
            "daft punk": ("electronic", "french house synthpop", "FR", "groovy", 120, 0.80, 0.95),
            "harry styles": ("pop", "synth pop rock", "UK", "upbeat", 122, 0.76, 0.95),
            "billie eilish": ("pop", "alt pop", "US", "atmospheric", 108, 0.58, 0.96),
            "lady gaga": ("pop", "dance pop ballad", "US", "dramatic", 116, 0.74, 0.96),
            "bruno mars": ("pop", "funk soul pop", "US", "groovy", 118, 0.78, 0.97),
            "sabrina carpenter": ("pop", "dance pop", "US", "upbeat", 120, 0.78, 0.94)
        ]
        
        for (key, val) in knownProfiles {
            if primaryArtist == key || primaryArtist.contains(key) {
                return RadioTrackProfile(
                    genre: val.genre,
                    subgenre: val.subgenre,
                    countryOrigin: val.country,
                    mood: val.mood,
                    tempoBPM: val.bpm,
                    energyLevel: val.energy,
                    popularityTier: val.pop,
                    primaryArtist: primaryArtist
                )
            }
        }
        
        // 2. Heuristic classification from track title/album/artist keywords when artist isn't in static table
        let isIndonesian = combined.range(of: #"\b(yang|dan|di|ke|aku|kau|kamu|cinta|hati|malam|rinduku|kangen|separuh|mimpi|lagu|indonesia)\b"#, options: .regularExpression) != nil
        let country = isIndonesian ? "ID" : "INTL"
        
        if combined.contains("metal") || combined.contains("hardcore") || combined.contains("punk") {
            return RadioTrackProfile(genre: "rock", subgenre: "heavy rock", countryOrigin: country, mood: "intense", tempoBPM: 138, energyLevel: 0.90, popularityTier: 0.75, primaryArtist: primaryArtist)
        } else if combined.contains("rock") || combined.contains("indie") || combined.contains("alternative") {
            return RadioTrackProfile(genre: "rock", subgenre: "alternative rock", countryOrigin: country, mood: "anthemic", tempoBPM: 124, energyLevel: 0.78, popularityTier: 0.80, primaryArtist: primaryArtist)
        } else if combined.contains("edm") || combined.contains("house") || combined.contains("techno") || combined.contains("synth") || combined.contains("club") {
            return RadioTrackProfile(genre: "electronic", subgenre: "electronic dance", countryOrigin: country, mood: "groovy", tempoBPM: 126, energyLevel: 0.84, popularityTier: 0.80, primaryArtist: primaryArtist)
        } else if combined.contains("jazz") || combined.contains("piano") || combined.contains("lofi") || combined.contains("lo-fi") || combined.contains("chill") {
            return RadioTrackProfile(genre: "chill", subgenre: "acoustic chill", countryOrigin: country, mood: "calm", tempoBPM: 88, energyLevel: 0.35, popularityTier: 0.75, primaryArtist: primaryArtist)
        } else if isIndonesian {
            return RadioTrackProfile(genre: "pop rock", subgenre: "indonesian pop rock", countryOrigin: "ID", mood: "melancholic", tempoBPM: 115, energyLevel: 0.64, popularityTier: 0.85, primaryArtist: primaryArtist)
        } else {
            return RadioTrackProfile(genre: "pop", subgenre: "contemporary pop", countryOrigin: country, mood: "upbeat", tempoBPM: 118, energyLevel: 0.72, popularityTier: 0.82, primaryArtist: primaryArtist)
        }
    }
    
    /// Evaluates multi-factor similarity between a seed track and a candidate track.
    /// Returns nil if the candidate violates strict relevance rules (e.g., only 1 matching attribute, conflicting genre/mood/tempo, or mismatched version).
    public static func evaluateCandidate(
        seed: Track,
        seedProfile: RadioTrackProfile,
        candidate: Track,
        excludedTrackIds: Set<String>,
        excludedTitleArtistKeys: Set<String>
    ) -> (score: Double, matchedAttributes: Int, primaryArtist: String)? {
        // 1. Exclude seed track and any already-played/duplicate track
        if candidate.id == seed.id || excludedTrackIds.contains(candidate.id) {
            return nil
        }
        let seedNormTitle = TrackVersionMatcher.normalizeCoreTitle(seed.title)
        let candNormTitle = TrackVersionMatcher.normalizeCoreTitle(candidate.title)
        let candPrimaryArtist = TrackVersionMatcher.normalizeArtists(candidate.artist).first ?? candidate.artist.lowercased()
        let dedupKey = "\(candNormTitle)|\(candPrimaryArtist)"
        if candNormTitle.isEmpty || candNormTitle == seedNormTitle || excludedTitleArtistKeys.contains(dedupKey) {
            return nil
        }
        
        // 2. Version consistency: if seed is studio, do not pollute radio with karaoke/sped-up/slowed/live/instrumental
        let seedVersion = TrackVersionMatcher.detectVersion(title: seed.title, album: seed.album)
        let candVersion = TrackVersionMatcher.detectVersion(title: candidate.title, album: candidate.album)
        if seedVersion == .studio && candVersion != .studio {
            return nil
        }
        
        // 3. Reject short clips (< 60s)
        if candidate.duration > 0 && candidate.duration < 60 {
            return nil
        }
        
        let candProfile = profile(for: candidate)
        
        // 4. Strict genre & energy guardrails: reject jarring genre/tempo/energy clashes
        let energyDiff = abs(seedProfile.energyLevel - candProfile.energyLevel)
        let bpmDiff = abs(seedProfile.tempoBPM - candProfile.tempoBPM)
        if energyDiff > 0.35 || bpmDiff > 32 {
            return nil
        }
        
        // Check multi-factor attribute matches
        var matchedAttributes = 0
        var totalScore: Double = 0
        
        // Factor A: Genre & Subgenre
        if seedProfile.subgenre == candProfile.subgenre {
            matchedAttributes += 2
            totalScore += 32.0
        } else if seedProfile.genre == candProfile.genre ||
                  (seedProfile.genre.contains("rock") && candProfile.genre.contains("rock")) ||
                  (seedProfile.genre.contains("pop") && candProfile.genre.contains("pop")) {
            matchedAttributes += 1
            totalScore += 20.0
        } else {
            // Incompatible macro-genre
            return nil
        }
        
        // Factor B: Country / Musical Origin
        if seedProfile.countryOrigin == candProfile.countryOrigin {
            matchedAttributes += 1
            totalScore += 18.0
        } else if seedProfile.countryOrigin == "ID" || candProfile.countryOrigin == "ID" {
            // Keep Indonesian radio cohesive with Indonesian catalog unless closely matched
            return nil
        } else if ["UK", "US", "CA", "IE", "FR", "INTL"].contains(seedProfile.countryOrigin) &&
                  ["UK", "US", "CA", "IE", "FR", "INTL"].contains(candProfile.countryOrigin) {
            matchedAttributes += 1
            totalScore += 12.0
        }
        
        // Factor C: Mood & Atmosphere
        let compatibleMoodGroups: [Set<String>] = [
            ["melancholic", "romantic", "nostalgic", "emotional", "warm"],
            ["anthemic", "uplifting", "energetic", "groovy", "upbeat", "powerful", "melodic"],
            ["intense", "dramatic", "raw", "brooding", "rebellious"],
            ["atmospheric", "nocturnal", "calm", "groovy"]
        ]
        if seedProfile.mood == candProfile.mood {
            matchedAttributes += 1
            totalScore += 16.0
        } else if compatibleMoodGroups.contains(where: { $0.contains(seedProfile.mood) && $0.contains(candProfile.mood) }) {
            matchedAttributes += 1
            totalScore += 11.0
        }
        
        // Factor D: Tempo & BPM proximity
        if bpmDiff <= 12 {
            matchedAttributes += 1
            totalScore += 12.0
        } else if bpmDiff <= 22 {
            matchedAttributes += 1
            totalScore += 7.0
        }
        
        // Factor E: Energy & Musical Style consistency
        if energyDiff <= 0.15 {
            matchedAttributes += 1
            totalScore += 12.0
        } else if energyDiff <= 0.25 {
            matchedAttributes += 1
            totalScore += 7.0
        }
        
        // Factor F: Popularity alignment
        if abs(seedProfile.popularityTier - candProfile.popularityTier) <= 0.18 {
            matchedAttributes += 1
            totalScore += 10.0
        }
        
        // Strict Requirement: Do NOT consider a song relevant based on only one matching attribute!
        // Require at least 3 matched musical attributes and a strong composite score.
        guard matchedAttributes >= 3 && totalScore >= 55.0 else {
            return nil
        }
        
        return (score: totalScore, matchedAttributes: matchedAttributes, primaryArtist: candPrimaryArtist)
    }
    
    /// Filters, scores, deduplicates, and caps artist repetition (max 2 songs per artist, never consecutive) for a cohesive Spotify-grade Radio queue.
    public static func rankAndFilterRadioCandidates(
        seed: Track,
        candidates: [Track],
        sessionHistoryIds: Set<String> = [],
        maxResults: Int = 20,
        maxPerArtist: Int = 2
    ) -> [Track] {
        let seedProfile = profile(for: seed)
        var excludedIds = sessionHistoryIds
        excludedIds.insert(seed.id)
        
        var seenTitleArtist = Set<String>()
        let seedPrimaryArtist = seedProfile.primaryArtist
        seenTitleArtist.insert("\(TrackVersionMatcher.normalizeCoreTitle(seed.title))|\(seedPrimaryArtist)")
        
        var scoredList: [(track: Track, score: Double, artist: String)] = []
        
        for cand in candidates {
            if let eval = evaluateCandidate(
                seed: seed,
                seedProfile: seedProfile,
                candidate: cand,
                excludedTrackIds: excludedIds,
                excludedTitleArtistKeys: seenTitleArtist
            ) {
                let normKey = "\(TrackVersionMatcher.normalizeCoreTitle(cand.title))|\(eval.primaryArtist)"
                seenTitleArtist.insert(normKey)
                excludedIds.insert(cand.id)
                scoredList.append((track: cand, score: eval.score, artist: eval.primaryArtist))
            }
        }
        
        // Sort by highest multi-attribute relevance score
        scoredList.sort { $0.score > $1.score }
        
        // Enforce artist diversity cap (no excessive repetition of the same artist; max `maxPerArtist` per artist, and max 1 for the seed artist itself)
        var artistCounts: [String: Int] = [:]
        var filteredPool: [(track: Track, artist: String)] = []
        for item in scoredList {
            let limit = (item.artist == seedPrimaryArtist) ? 1 : maxPerArtist
            let count = artistCounts[item.artist, default: 0]
            if count < limit {
                artistCounts[item.artist] = count + 1
                filteredPool.append((track: item.track, artist: item.artist))
            }
        }
        
        // Interleave so the same artist never plays back-to-back
        var finalQueue: [Track] = []
        var remaining = filteredPool
        var lastArtist: String = seedPrimaryArtist
        
        while !remaining.isEmpty && finalQueue.count < maxResults {
            if let nonRepeatIdx = remaining.firstIndex(where: { $0.artist != lastArtist }) {
                let chosen = remaining.remove(at: nonRepeatIdx)
                finalQueue.append(chosen.track)
                lastArtist = chosen.artist
            } else {
                let chosen = remaining.removeFirst()
                finalQueue.append(chosen.track)
                lastArtist = chosen.artist
            }
        }
        
        return finalQueue
    }
}
