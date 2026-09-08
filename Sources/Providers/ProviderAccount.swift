import Foundation

/// Whose readings these are.
///
/// Worth showing plainly, because Codenotch never signs in — it borrows a
/// credential the owning tool already holds, and there is nothing stopping that
/// credential belonging to a different account than the one you are sitting in
/// front of. It happened during development: a browser sign-in created a second,
/// empty Cursor account, and the notch spent an afternoon faithfully reporting
/// somebody else's zero. A visible email would have caught it in seconds.
struct ProviderAccount: Equatable {
    /// Email or display name, where the credential carries one.
    let label: String?
    /// The plan, named the way the provider names it.
    let plan: String?
    /// Which app's credential this borrows.
    let source: String
    /// The provider's own usage page, for checking this against the source.
    let manageURL: URL?

    /// One line for the settings row.
    var summary: String {
        [label, plan.map { $0.capitalized }, "via \(source)"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// Where to go when a provider has no usable credential.
///
/// Codenotch cannot sign anyone in — it reads a credential the owning tool
/// holds — so the most it can honestly do is open that tool, or say what to do
/// when there is nothing to open.
enum SignInRoute: Equatable {
    /// The provider owns the session and can present its own sign-in window.
    /// The only case where Codenotch genuinely signs anyone in or out.
    case modal(name: String)
    /// Launch the app that owns the credential.
    case openApp(bundleID: String, name: String)
    /// Nothing to launch; Claude Code is a command, not an application.
    case guidance(String)

    var actionTitle: String? {
        switch self {
        case .modal(let name):     return "登录 \(name)"
        case .openApp(_, let name): return "打开 \(name)"
        case .guidance:            return nil
        }
    }

    var explanation: String {
        switch self {
        case .modal(let name):      return "登录 \(name) 后读取此账号。"
        case .openApp(_, let name): return "请先在 \(name) 中登录此账号。"
        case .guidance(let text):   return text
        }
    }

    /// How to change which account is being read.
    ///
    /// Always somewhere else: the credential belongs to the tool that issued
    /// it, so switching accounts is that tool's business and this can only say
    /// where to go.
    var switchHint: String {
        switch self {
        case .modal(let name):      return "在 \(name) 窗口中退出后，可登录其他账号。"
        case .openApp(_, let name): return "在 \(name) 中切换账号，面板会随之更新。"
        case .guidance:             return "在原工具中切换账号，面板会随之更新。"
        }
    }

    /// What switching a provider off does and does not reach, said plainly, so
    /// nobody switches off here expecting to be signed out of the tool as well.
    var signOutCaveat: String {
        switch self {
        case .modal(let name):
            return "退出由 CodenotchT 管理的 \(name) 会话。"
        case .openApp(_, let name):
            return "\(name) 中仍保持登录，如需退出请在该工具中操作。"
        case .guidance:
            return "原工具中的账号仍保持登录。"
        }
    }
}

extension UsageProvider {
    /// Providers that borrow no credential have no account to show.
    ///
    /// A default for a requirement *declared in the protocol* is fine — the
    /// requirement keeps dispatch dynamic, so an implementation still wins. It
    /// is declaring a method only in an extension that quietly breaks.
    func account() -> ProviderAccount? { nil }

    var signInRoute: SignInRoute {
        .guidance("请先在此账号所属的工具中登录。")
    }

    /// Nothing of our own to discard, by default.
    func signOut() async {}

    /// No modal of our own to show, by default — `UsageStore.signIn` falls back
    /// to the route.
    func presentSignIn() {}

    /// Providers that hold nothing in memory have nothing to drop.
    func forgetCachedCredential() {}
}

/// A provider as the settings sheet needs it.
struct ProviderSummary: Identifiable, Equatable {
    /// Whether this provider's credential lives in the keychain, and so can be
    /// refused. Codex still reads an ordinary file and never prompts. Cursor
    /// does too when the editor is signed in, but `cursor-agent` files its
    /// JWT in the login keychain — without this flag a declined prompt would
    /// have no "允许访问…" to put the dialogue back.
    var usesKeychain: Bool {
        ClaudeProfile.isClaude(providerID: id) || id == "gemini" || id == "cursor"
    }

    let id: String
    let name: String
    let glyph: ProviderGlyph
    let account: ProviderAccount?
    let signIn: SignInRoute
    /// Whether macOS refused this credential on the last fetch — the one state
    /// "允许访问…" can actually repair.
    ///
    /// Deliberately *not* read off the snapshot's status. A refusal leaves the
    /// last reading standing and its status untouched, because the number is
    /// still true; the refusal itself is remembered separately by the store.
    /// Offering to re-ask macOS for a credential it is already handing over is a
    /// cure for an illness the provider does not have, and a button that does
    /// nothing is indistinguishable from a broken one.
    var wasRefusedAccess: Bool = false
}
