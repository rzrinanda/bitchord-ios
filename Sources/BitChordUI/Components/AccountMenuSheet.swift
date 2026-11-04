import SwiftUI
import WebKit

public struct AccountMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showingAddAccountAlert: Bool = false
    @State private var showingGoogleLogin: Bool = false
    @State private var showingAddAccountDialog: Bool = false
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
                                    HStack(spacing: 6) {
                                        Text(account.displayName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        if account.isGoogleAccount {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 13))
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    
                                    Text(account.isGoogleAccount ? "\(account.handle) • Google" : account.handle)
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
                        showingAddAccountDialog = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.cyan)
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
                        showingGoogleLogin = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "globe")
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(.cyan)
                            Text("Connect Google Account")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.cyan)
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
            .sheet(isPresented: $showingGoogleLogin) {
                GoogleLoginSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.large])
            }
            .confirmationDialog("Tambah Akun", isPresented: $showingAddAccountDialog, titleVisibility: .visible) {
                Button("Hubungkan Akun Google (Disarankan)") {
                    showingGoogleLogin = true
                }
                Button("Tambah Akun Manual") {
                    showingAddAccountAlert = true
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Hubungkan akun Google/YouTube Music Anda untuk mendengarkan lagu full version dan sinkronisasi playlist.")
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

// MARK: - Google Login Sheet (In-App Google / YouTube Music Auth)
public struct GoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager = AccountManager.shared
    @State private var isLoading: Bool = true
    @State private var pageTitle: String = "Masuk dengan Google"
    @State private var currentURL: String = ""
    @State private var loginSuccessMessage: String? = nil
    
    private let loginURL = "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&prompt=select_account&continue=https%3A%2F%2Fmusic.youtube.com%2F"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .padding(.vertical, 8)
                    }
                    
                    GoogleLoginWebView(
                        initialURL: loginURL,
                        isLoading: $isLoading,
                        pageTitle: $pageTitle,
                        currentURL: $currentURL,
                        onLoginCompleted: { displayName, handle, avatarURL, cookie in
                            accountManager.addGoogleAccount(
                                displayName: displayName,
                                handle: handle,
                                avatarURL: avatarURL,
                                cookie: cookie
                            )
                            loginSuccessMessage = "Berhasil terhubung sebagai \(displayName) (\(handle))"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                dismiss()
                            }
                        }
                    )
                }
                
                if let success = loginSuccessMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            Text(success)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6).opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Hubungkan Akun Google")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#if os(iOS)
struct GoogleLoginWebView: UIViewRepresentable {
    let initialURL: String
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var currentURL: String
    let onLoginCompleted: (String, String, URL?, String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        
        if let url = URL(string: initialURL) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GoogleLoginWebView
        private var hasCompleted = false
        
        init(_ parent: GoogleLoginWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.pageTitle = webView.title ?? "Google Sign-in"
                self.parent.currentURL = webView.url?.absoluteString ?? ""
            }
            
            guard let url = webView.url?.absoluteString, !hasCompleted else { return }
            
            if url.starts(with: "https://music.youtube.com") {
                checkAuthAndCapture(webView: webView)
            }
        }
        
        private func checkAuthAndCapture(webView: WKWebView) {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.hasCompleted else { return }
                
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                let hasSapisid = cookies.contains { $0.name == "SAPISID" || $0.name == "__Secure-3PAPISID" || $0.name == "__Secure-1PAPISID" }
                
                if hasSapisid {
                    let jsProbe = """
                    (function() {
                        try {
                            var cfg = window.ytcfg || {};
                            var get = function(k) { return cfg.get ? cfg.get(k) : null; };
                            var loggedIn = !!get('LOGGED_IN');
                            var dataSyncId = get('DATASYNC_ID') || '';
                            return JSON.stringify({
                                loggedIn: loggedIn,
                                dataSyncId: dataSyncId,
                                title: document.title || ''
                            });
                        } catch(e) {
                            return null;
                        }
                    })()
                    """
                    
                    webView.evaluateJavaScript(jsProbe) { result, _ in
                        let displayName = "Akun Google"
                        var handle = "@user"
                        
                        if let jsonStr = result as? String,
                           let data = jsonStr.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let dataSyncId = dict["dataSyncId"] as? String, !dataSyncId.isEmpty {
                                handle = "@\(dataSyncId.prefix(12))"
                            }
                        }
                        
                        self.hasCompleted = true
                        DispatchQueue.main.async {
                            self.parent.onLoginCompleted(displayName, handle, nil, cookieHeader)
                        }
                    }
                }
            }
        }
    }
}
#elseif os(macOS)
struct GoogleLoginWebView: NSViewRepresentable {
    let initialURL: String
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var currentURL: String
    let onLoginCompleted: (String, String, URL?, String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        if let url = URL(string: initialURL) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GoogleLoginWebView
        private var hasCompleted = false
        
        init(_ parent: GoogleLoginWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.currentURL = webView.url?.absoluteString ?? ""
            }
            guard let url = webView.url?.absoluteString, !hasCompleted else { return }
            if url.starts(with: "https://music.youtube.com") {
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                    guard let self = self, !self.hasCompleted else { return }
                    let header = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    self.hasCompleted = true
                    DispatchQueue.main.async {
                        self.parent.onLoginCompleted("Google Music User", "@google", nil, header)
                    }
                }
            }
        }
    }
}
#endif
