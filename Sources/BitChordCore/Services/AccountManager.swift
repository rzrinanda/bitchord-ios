import Foundation

public struct UserAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let avatarLetter: String
    public let memberSince: String
    
    public init(
        id: String = UUID().uuidString,
        displayName: String,
        handle: String,
        avatarLetter: String,
        memberSince: String = "11/26"
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatarLetter = avatarLetter
        self.memberSince = memberSince
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
