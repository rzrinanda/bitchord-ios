import SwiftUI

public struct AccountMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showingAddAccountAlert: Bool = false
    @State private var newDisplayName: String = ""
    @State private var newHandle: String = ""
    @State private var showingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Switch account")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text(accountManager.activeAccount.handle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Account List
                VStack(spacing: 4) {
                    ForEach(accountManager.accounts) { account in
                        Button {
                            accountManager.switchAccount(to: account)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                // Avatar circle
                                ZStack {
                                    Circle()
                                        .fill(account.id == accountManager.activeAccount.id ? Color.cyan.opacity(0.8) : Color.gray.opacity(0.3))
                                        .frame(width: 42, height: 42)
                                    Text(account.avatarLetter)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(account.handle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if account.id == accountManager.activeAccount.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                
                // Action Buttons
                VStack(spacing: 2) {
                    Button {
                        showingAddAccountAlert = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Add account")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        // Manage accounts info
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.2")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Manage accounts")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingSettings = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.primary)
                            Text("Settings")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .alert("Add BitChord Account", isPresented: $showingAddAccountAlert) {
                TextField("Display Name", text: $newDisplayName)
                TextField("Handle (e.g. @username)", text: $newHandle)
                Button("Cancel", role: .cancel) {
                    newDisplayName = ""
                    newHandle = ""
                }
                Button("Add") {
                    if !newDisplayName.isEmpty {
                        accountManager.addAccount(
                            displayName: newDisplayName,
                            handle: newHandle.isEmpty ? "@\(newDisplayName.lowercased())" : newHandle
                        )
                        newDisplayName = ""
                        newHandle = ""
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
