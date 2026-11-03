import Foundation

public struct UserAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let avatarLetter: String
    public let avatarURL: URL?
    public let memberSince: String
    public let cookie: String?
    public let isGoogleAccount: Bool
    
    public init(
        id: String = UUID().uuidString,
        displayName: String,
        handle: String,
        avatarLetter: String,
        avatarURL: URL? = nil,
        memberSince: String = "11/26",
        cookie: String? = nil,
        isGoogleAccount: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatarLetter = avatarLetter
        self.avatarURL = avatarURL
        self.memberSince = memberSince
        self.cookie = cookie
        self.isGoogleAccount = isGoogleAccount
    }
}

@MainActor
public final class AccountManager: ObservableObject {
    public static let shared = AccountManager()
    
    @Published public private(set) var accounts: [UserAccount] = []
    @Published public private(set) var activeAccount: UserAccount
    
    private let accountsKey = "BitChord.Accounts.List"
    private let activeAccountIdKey = "BitChord.Accounts.ActiveId"
    
    public init() {
        // Seed default accounts matching user's car Head Unit (Photo 5)
        let primary = UserAccount(
            id: "acc_rzr",
            displayName: "rzrinanda",
            handle: "@rzrinanda",
            avatarLetter: "r",
            memberSince: "11/26"
        )
        let secondary = UserAccount(
            id: "acc_rizal",
            displayName: "Rizal Zulfikar Rinanda",
            handle: "@rizalzulfikarrinanda171",
            avatarLetter: "R",
            memberSince: "11/26"
        )
        
        self.accounts = [secondary, primary]
        self.activeAccount = primary
        
        load()
    }
    
    public func switchAccount(to account: UserAccount) {
        self.activeAccount = account
        UserDefaults.standard.set(account.id, forKey: activeAccountIdKey)
        
        // Propagate cookies to YTMusicClient and YouTubeAudioBridge
        Task {
            await YTMusicClient.shared.setSessionCookies(account.cookie)
            await MainActor.run {
                YouTubeAudioBridge.shared.refreshSession()
            }
        }
    }
    
    public func addGoogleAccount(
        displayName: String,
        handle: String,
        avatarURL: URL? = nil,
        cookie: String
    ) {
        let cleanHandle = handle.hasPrefix("@") ? handle : "@\(handle)"
        let letter = String(displayName.prefix(1)).uppercased()
        let newAcc = UserAccount(
            displayName: displayName,
            handle: cleanHandle,
            avatarLetter: letter.isEmpty ? "G" : letter,
            avatarURL: avatarURL,
            cookie: cookie,
            isGoogleAccount: true
        )
        if let idx = accounts.firstIndex(where: { $0.handle == cleanHandle }) {
            accounts[idx] = newAcc
        } else {
            accounts.append(newAcc)
        }
        activeAccount = newAcc
        save()
        
        Task {
            await YTMusicClient.shared.setSessionCookies(cookie)
            await MainActor.run {
                YouTubeAudioBridge.shared.refreshSession()
            }
        }
    }
    
    public func removeAccount(_ account: UserAccount) {
        accounts.removeAll { $0.id == account.id }
        if activeAccount.id == account.id, let first = accounts.first {
            switchAccount(to: first)
        }
        save()
    }
    
    public func addAccount(displayName: String, handle: String) {
        let cleanHandle = handle.hasPrefix("@") ? handle : "@\(handle)"
        let letter = String(displayName.prefix(1)).lowercased()
        let newAcc = UserAccount(
            displayName: displayName,
            handle: cleanHandle,
            avatarLetter: letter
        )
        accounts.append(newAcc)
        activeAccount = newAcc
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
        UserDefaults.standard.set(activeAccount.id, forKey: activeAccountIdKey)
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let list = try? JSONDecoder().decode([UserAccount].self, from: data), !list.isEmpty {
            self.accounts = list
            let activeId = UserDefaults.standard.string(forKey: activeAccountIdKey) ?? list.first?.id
            if let matched = list.first(where: { $0.id == activeId }) {
                self.activeAccount = matched
            } else if let first = list.first {
                self.activeAccount = first
            }
        }
    }
}
