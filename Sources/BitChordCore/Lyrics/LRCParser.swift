import Foundation

public final class LRCParser: Sendable {
    public init() {}
    
    /// Parses LRC content string into a structured `Lyrics` object.
    /// Handles standard line timestamps `[mm:ss.xx]`, multiple timestamps per line,
    /// and enhanced syllable timestamps `<mm:ss.xx>word`.
    public func parse(trackId: String, lrcContent: String, provider: String = "LRCLIB") -> Lyrics {
        let lines = lrcContent.components(separatedBy: .newlines)
        var parsedLines: [LyricLine] = []
        var plainLines: [String] = []
        
        let timestampRegex = try? NSRegularExpression(pattern: "\\[(\\d{1,2}):(\\d{2})\\.(\\d{2,3})\\]")
        let syllableRegex = try? NSRegularExpression(pattern: "<(\\d{1,2}):(\\d{2})\\.(\\d{2,3})>([^<]*)")
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            
            // Skip ID tags like [ar:Artist], [ti:Title], [length:03:45]
            if line.hasPrefix("[") && line.contains(":") {
                let tagKey = line.dropFirst().prefix(while: { $0 != ":" }).lowercased()
                if ["ar", "ti", "al", "by", "offset", "length", "re", "ve"].contains(tagKey) {
                    continue
                }
            }
            
            let nsString = line as NSString
            let matches = timestampRegex?.matches(in: line, range: NSRange(location: 0, length: nsString.length)) ?? []
            
            if matches.isEmpty {
                plainLines.append(line)
                continue
            }
            
            // Extract the lyrics text after the timestamp tags
            var textStartIndex = 0
            if let lastMatch = matches.last {
                textStartIndex = lastMatch.range.location + lastMatch.range.length
            }
            let rawText = textStartIndex < nsString.length ? nsString.substring(from: textStartIndex).trimmingCharacters(in: .whitespaces) : ""
            
            // Extract syllable timing if present
            var syllables: [LyricSyllable] = []
            if let sRegex = syllableRegex {
                let sMatches = sRegex.matches(in: rawText, range: NSRange(location: 0, length: (rawText as NSString).length))
                var previousTime: TimeInterval?
                
                for sMatch in sMatches {
                    if sMatch.numberOfRanges >= 5 {
                        let minStr = (rawText as NSString).substring(with: sMatch.range(at: 1))
                        let secStr = (rawText as NSString).substring(with: sMatch.range(at: 2))
                        let msStr = (rawText as NSString).substring(with: sMatch.range(at: 3))
                        let wordText = (rawText as NSString).substring(with: sMatch.range(at: 4))
                        
                        let time = Self.calculateTimestamp(min: minStr, sec: secStr, ms: msStr)
                        let duration: TimeInterval
                        if let prev = previousTime {
                            duration = max(0.1, time - prev)
                        } else {
                            duration = 0.25
                        }
                        syllables.append(LyricSyllable(text: wordText, startTime: time, duration: duration))
                        previousTime = time
                    }
                }
            }
            
            // Clean text (strip syllable tags for clean display)
            let cleanedText = (syllables.isEmpty ? rawText : rawText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                .trimmingCharacters(in: .whitespaces)
            
            let isInstrumental = cleanedText.lowercased().contains("♪") || cleanedText.isEmpty
            
            // If line has multiple timestamps (e.g. repeated chorus [00:15.00][01:20.00]text), add line for each
            for match in matches {
                if match.numberOfRanges >= 4 {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let msStr = nsString.substring(with: match.range(at: 3))
                    let time = Self.calculateTimestamp(min: minStr, sec: secStr, ms: msStr)
                    
                    parsedLines.append(
                        LyricLine(
                            timestamp: time,
                            text: cleanedText,
                            syllables: syllables,
                            isInstrumental: isInstrumental
                        )
                    )
                }
            }
        }
        
        parsedLines.sort { $0.timestamp < $1.timestamp }
        let fullPlainText = parsedLines.map { $0.text }.joined(separator: "\n")
        
        return Lyrics(
            trackId: trackId,
            isSynced: !parsedLines.isEmpty,
            lines: parsedLines,
            plainLyrics: fullPlainText.isEmpty ? plainLines.joined(separator: "\n") : fullPlainText,
            provider: provider,
            source: .network
        )
    }
    
    private static func calculateTimestamp(min: String, sec: String, ms: String) -> TimeInterval {
        let minutes = Double(min) ?? 0
        let seconds = Double(sec) ?? 0
        let milliseconds: Double
        if ms.count == 2 {
            milliseconds = (Double(ms) ?? 0) * 10.0
        } else {
            milliseconds = Double(ms) ?? 0
        }
        return (minutes * 60.0) + seconds + (milliseconds / 1000.0)
    }
}
