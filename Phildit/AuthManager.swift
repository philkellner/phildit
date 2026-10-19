import Foundation

/// Reddit OAuth2 for an "installed app" client: authorization-code flow with
/// no client secret (Basic auth with an empty password), tokens kept in the Keychain.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    static let redirectURI = "phildit://oauth"
    static let callbackScheme = "phildit"

    enum AuthError: LocalizedError {
        case missingClientID, badCallback, stateMismatch, denied(String), server(Int)
        var errorDescription: String? {
            switch self {
            case .missingClientID: return "Enter your Reddit client ID first."
            case .badCallback: return "Reddit returned an unexpected response."
            case .stateMismatch: return "Login response did not match the request. Try again."
            case .denied(let why): return "Reddit denied the login: \(why)."
            case .server(let c): return "Reddit token request failed (HTTP \(c))."
            }
        }
    }

    @Published var clientID: String {
        didSet { UserDefaults.standard.set(clientID, forKey: "redditClientID") }
    }
    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var username: String?

    private var accessToken: String?
    private var expiry = Date.distantPast
    private var pendingState: String?

    private init() {
        clientID = UserDefaults.standard.string(forKey: "redditClientID") ?? ""
        isLoggedIn = Keychain.get("refreshToken") != nil
        username = UserDefaults.standard.string(forKey: "redditUsername")
    }

    func authorizeURL() throws -> URL {
        let id = clientID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { throw AuthError.missingClientID }
        let state = UUID().uuidString
        pendingState = state
        var c = URLComponents(string: "https://www.reddit.com/api/v1/authorize.mobile")!
        c.queryItems = [
            .init(name: "client_id", value: id),
            .init(name: "response_type", value: "code"),
            .init(name: "state", value: state),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "duration", value: "permanent"),
            .init(name: "scope", value: "identity mysubscriptions read history"),
        ]
        return c.url!
    }

    func handleCallback(_ url: URL) async throws {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ n: String) -> String? { items.first { $0.name == n }?.value }
        if let err = value("error") { throw AuthError.denied(err) }
        guard value("state") == pendingState, pendingState != nil else { throw AuthError.stateMismatch }
        pendingState = nil
        guard let code = value("code") else { throw AuthError.badCallback }
        let t = try await tokenRequest(["grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirectURI])
        store(t)
        if let me = try? await RedditClient().me() {
            username = me
            UserDefaults.standard.set(me, forKey: "redditUsername")
        }
    }

    /// A non-expired access token, refreshing if needed; nil when logged out.
    func validToken() async throws -> String? {
        guard isLoggedIn, let refresh = Keychain.get("refreshToken") else { return nil }
        if let t = accessToken, expiry > Date().addingTimeInterval(60) { return t }
        let t = try await tokenRequest(["grant_type": "refresh_token", "refresh_token": refresh])
        store(t)
        return t.accessToken
    }

    func logout() {
        Keychain.delete("refreshToken")
        UserDefaults.standard.removeObject(forKey: "redditUsername")
        accessToken = nil; expiry = .distantPast; username = nil; isLoggedIn = false
    }

    private func store(_ t: TokenResponse) {
        accessToken = t.accessToken
        expiry = Date().addingTimeInterval(TimeInterval(t.expiresIn))
        if let r = t.refreshToken { Keychain.set(r, for: "refreshToken") }
        isLoggedIn = true
    }

    private func tokenRequest(_ params: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://www.reddit.com/api/v1/access_token")!)
        req.httpMethod = "POST"
        let basic = Data("\(clientID.trimmingCharacters(in: .whitespaces)):".utf8).base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(RedditClient.userAgent, forHTTPHeaderField: "User-Agent")
        var c = URLComponents()
        c.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = c.percentEncodedQuery?.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw AuthError.server(code) }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
