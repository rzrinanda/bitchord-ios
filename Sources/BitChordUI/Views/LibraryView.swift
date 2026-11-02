import SwiftUI

public struct LibraryView: View {
    @ObservedObject var engine = AudioPlayerEngine.shared
    @State private var offlineLyricsCount: Int = 0
    @State private var offlineStorageSize: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        Text("Liked Songs")
                            .font(.headline)
                    } label: {
                        Label("Liked Songs", systemImage: "heart.fill")
                            .foregroundColor(.red)
                    }
                    
                    NavigationLink {
                        Text("Playlists")
                    } label: {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    
                    NavigationLink {
                        Text("Downloaded Music")
                    } label: {
                        Label("Downloaded Music", systemImage: "arrow.down.circle")
                    }
                }
                
                // Offline Lyrics Manager
                Section("Offline Lyrics Storage") {
                    HStack {
                        Label("Cached Lyrics", systemImage: "quote.bubble.fill")
                        Spacer()
                        Text("\(offlineLyricsCount) Tracks (\(offlineStorageSize))")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("Configure Storage & Auto-Download")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Library")
            .task {
                offlineLyricsCount = await LyricsManager.shared.getDownloadedLyricsCount()
                offlineStorageSize = await LyricsManager.shared.getStorageUsageString()
            }
        }
    }
}
