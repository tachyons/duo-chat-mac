import SwiftUI
import Combine
import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var tokenExpiryWarning = false
    @Published var authenticationError: AuthenticationError?
    @Published var isAuthenticating = false
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var gitlabURL: String?
    private var clientID: String?
    
    // PKCE parameters
    private var codeVerifier: String?
    private var codeChallenge: String?
    private var state: String?
    
    private let userDefaults = UserDefaults.standard
    private var tokenCheckTimer: Timer?
    private var authSession: ASWebAuthenticationSession?
    
    // Constants
    private let redirectURI = "com.gitlabduochat://oauth/callback"
    private let scopes = "api read_user"
    
    override init() {
        super.init()
        loadStoredCredentials()
        startTokenMonitoring()
    }
    
    deinit {
        /*stopTokenMonitoring*/()
        authSession?.cancel()
    }
    
    // MARK: - Public Methods
    
    func signIn(gitlabURL: String, clientID: String) async throws {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        authenticationError = nil
        
        self.gitlabURL = gitlabURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try await performOAuthFlow()
        } catch {
            authenticationError = error as? AuthenticationError ?? .unknown(error.localizedDescription)
            isAuthenticating = false
            throw error
        }
    }
    
    func signOut() {
        authSession?.cancel()
        clearStoredCredentials()
        stopTokenMonitoring()
        
        isAuthenticated = false
        tokenExpiryWarning = false
        authenticationError = nil
        isAuthenticating = false
        
        // Clear PKCE parameters
        codeVerifier = nil
        codeChallenge = nil
        state = nil
    }
    
    func refreshTokenIfNeeded() async {
        guard let tokenExpiry = tokenExpiry,
              tokenExpiry.timeIntervalSinceNow < 300, // 5 minutes
              let _ = refreshToken else { return }
        
        do {
            try await refreshAccessToken()
        } catch {
            print("Token refresh failed: \(error)")
            // If refresh fails, sign out user
            signOut()
        }
    }
    
    
    private func performOAuthFlow() async throws {
        // Step 1: Generate PKCE parameters
        try generatePKCEParameters()
        
        // Step 2: Build authorization URL
        guard let authURL = buildAuthorizationURL() else {
            throw AuthenticationError.invalidURL
        }
        
        // Step 3: Start web authentication session
        let authCode = try await startWebAuthenticationSession(with: authURL)
        
        print("auth code \(authCode)")
        
        // Step 4: Exchange authorization code for tokens
        try await exchangeCodeForTokens(authCode)
        
        isAuthenticating = false
        isAuthenticated = true
    }
    
    private func generatePKCEParameters() throws {
        // Generate code verifier (random string)
        codeVerifier = generateCodeVerifier()
        
        // Generate code challenge (SHA256 hash of verifier, base64url encoded)
        guard let verifier = codeVerifier else {
            throw AuthenticationError.pkceGenerationFailed
        }
        
        codeChallenge = try generateCodeChallenge(from: verifier)
        
        // Generate state parameter for CSRF protection
        state = generateState()
    }
    
    private func generateCodeVerifier() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }
    
    private func generateCodeChallenge(from verifier: String) throws -> String {
        guard let data = verifier.data(using: .utf8) else {
            throw AuthenticationError.pkceGenerationFailed
        }
        
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }
    
    private func generateState() -> String {
        let data = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }
    
    private func buildAuthorizationURL() -> URL? {
        guard let gitlabURL = gitlabURL,
              let clientID = clientID,
              let codeChallenge = codeChallenge,
              let state = state,
              let baseURL = URL(string: gitlabURL) else {
            return nil
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("oauth/authorize"), resolvingAgainstBaseURL: false)
        
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    private func startWebAuthenticationSession(with url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "com.gitlabduochat"
            ) { [weak self] callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: AuthenticationError.userCancelled)
                    } else {
                        continuation.resume(throwing: AuthenticationError.authSessionFailed(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthenticationError.noCallbackURL)
                    return
                }
                
                do {
                    let authCode = try self?.extractAuthorizationCode(from: callbackURL)
                    guard let code = authCode else {
                        continuation.resume(throwing: AuthenticationError.noAuthorizationCode)
                        return
                    }
                    continuation.resume(returning: code)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            
            if !authSession!.start() {
                continuation.resume(throwing: AuthenticationError.authSessionStartFailed)
            }
        }
    }
    
    private func extractAuthorizationCode(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw AuthenticationError.invalidCallbackURL
        }
        
        // Check for error in callback
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
            throw AuthenticationError.oauthError("\(error): \(errorDescription)")
        }
        
        // Verify state parameter
        let returnedState = queryItems.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw AuthenticationError.stateMismatch
        }
        
        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw AuthenticationError.noAuthorizationCode
        }
        
        return code
    }
    
    private func exchangeCodeForTokens(_ code: String) async throws {
        guard let gitlabURL = gitlabURL,
              let clientID = clientID,
              let codeVerifier = codeVerifier,
              let tokenURL = URL(string: "\(gitlabURL)/oauth/token") else {
            throw AuthenticationError.invalidURL
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let tokenRequest = TokenRequest(
            clientId: clientID,
            code: code,
            grantType: "authorization_code",
            redirectUri: redirectURI,
            codeVerifier: codeVerifier
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(tokenRequest)
        } catch {
            throw AuthenticationError.tokenRequestEncodingFailed
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthenticationError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                    throw AuthenticationError.tokenExchangeFailed(errorData.errorDescription ?? errorData.error)
                } else {
                    throw AuthenticationError.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            
            // Store tokens
            accessToken = tokenResponse.accessToken
            refreshToken = tokenResponse.refreshToken
            
            // Calculate expiry
            let expiresIn = tokenResponse.expiresIn ?? 7200 // Default to 2 hours
            tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            
            // Store credentials
            storeCredentials()
            
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.networkError(error.localizedDescription)
        }
    }
    
    private func refreshAccessToken() async throws {
        guard let gitlabURL = gitlabURL,
              let clientID = clientID,
              let refreshToken = refreshToken,
              let tokenURL = URL(string: "\(gitlabURL)/oauth/token") else {
            throw AuthenticationError.invalidURL
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let refreshRequest = RefreshTokenRequest(
            clientId: clientID,
            grantType: "refresh_token",
            refreshToken: refreshToken
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(refreshRequest)
        } catch {
            throw AuthenticationError.tokenRequestEncodingFailed
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthenticationError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                    throw AuthenticationError.tokenRefreshFailed(errorData.errorDescription ?? errorData.error)
                } else {
                    throw AuthenticationError.tokenRefreshFailed("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            // Update tokens
            accessToken = tokenResponse.accessToken
            if let newRefreshToken = tokenResponse.refreshToken {
                self.refreshToken = newRefreshToken
            }
            
            // Calculate expiry
            let expiresIn = tokenResponse.expiresIn ?? 7200
            tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            
            // Update stored credentials
            storeCredentials()
            
            // Clear expiry warning
            tokenExpiryWarning = false
            
            print("Access token refreshed successfully")
            
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Storage Methods
    
    private func loadStoredCredentials() {
        accessToken = Keychain.shared.get(key: "gitlab_access_token")
        refreshToken = Keychain.shared.get(key: "gitlab_refresh_token")
        gitlabURL = userDefaults.string(forKey: "gitlab_url")
        clientID = userDefaults.string(forKey: "gitlab_client_id")
        
        if let expiryString = userDefaults.string(forKey: "gitlab_token_expiry"),
           let expiry = ISO8601DateFormatter().date(from: expiryString) {
            tokenExpiry = expiry
        }
        
        // Check if credentials are valid and not expired
        if let accessToken = accessToken,
           !accessToken.isEmpty,
           let tokenExpiry = tokenExpiry,
           tokenExpiry > Date() {
            isAuthenticated = true
        } else {
            clearStoredCredentials()
        }
    }
    
    private func storeCredentials() {
        // Store sensitive tokens in Keychain
        if let accessToken = accessToken {
            Keychain.shared.set(key: "gitlab_access_token", value: accessToken)
        }
        if let refreshToken = refreshToken {
            Keychain.shared.set(key: "gitlab_refresh_token", value: refreshToken)
        }
        
        // Store non-sensitive data in UserDefaults
        userDefaults.set(gitlabURL, forKey: "gitlab_url")
        userDefaults.set(clientID, forKey: "gitlab_client_id")
        
        if let tokenExpiry = tokenExpiry {
            userDefaults.set(ISO8601DateFormatter().string(from: tokenExpiry), forKey: "gitlab_token_expiry")
        }
    }
    
    private func clearStoredCredentials() {
        // Clear Keychain
        Keychain.shared.delete(key: "gitlab_access_token")
        Keychain.shared.delete(key: "gitlab_refresh_token")
        
        // Clear UserDefaults
        userDefaults.removeObject(forKey: "gitlab_url")
        userDefaults.removeObject(forKey: "gitlab_client_id")
        userDefaults.removeObject(forKey: "gitlab_token_expiry")
        
        // Clear instance variables
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        gitlabURL = nil
        clientID = nil
    }
    
    // MARK: - Token Monitoring
    
    private func startTokenMonitoring() {
        tokenCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.checkTokenExpiry()
            }
        }
    }
    
    private func stopTokenMonitoring() {
        tokenCheckTimer?.invalidate()
        tokenCheckTimer = nil
    }
    
    private func checkTokenExpiry() {
        guard let tokenExpiry = tokenExpiry else { return }
        
        let timeUntilExpiry = tokenExpiry.timeIntervalSinceNow
        tokenExpiryWarning = timeUntilExpiry < 300 && timeUntilExpiry > 0 // 5 minutes
        
        // Auto-refresh if token expires in less than 1 minute and we have a refresh token
        if timeUntilExpiry < 60 && timeUntilExpiry > 0 && refreshToken != nil {
            Task {
                try? await refreshAccessToken()
            }
        }
        
        // Sign out if token is expired and refresh failed
        if timeUntilExpiry <= 0 {
            signOut()
        }
    }
    
    // MARK: - Public Accessors
    
    var currentAccessToken: String? {
        return accessToken
    }
    
    var currentGitLabURL: String? {
        return gitlabURL
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Data Models

struct TokenRequest: Codable {
    let clientId: String
    let code: String
    let grantType: String
    let redirectUri: String
    let codeVerifier: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case code
        case grantType = "grant_type"
        case redirectUri = "redirect_uri"
        case codeVerifier = "code_verifier"
    }
}

struct RefreshTokenRequest: Codable {
    let clientId: String
    let grantType: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct TokenErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case invalidURL
    case pkceGenerationFailed
    case userCancelled
    case authSessionFailed(String)
    case authSessionStartFailed
    case noCallbackURL
    case invalidCallbackURL
    case stateMismatch
    case oauthError(String)
    case noAuthorizationCode
    case tokenRequestEncodingFailed
    case invalidResponse
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitLab URL or configuration"
        case .pkceGenerationFailed:
            return "Failed to generate PKCE parameters"
        case .userCancelled:
            return "Authentication was cancelled by user"
        case .authSessionFailed(let message):
            return "Authentication session failed: \(message)"
        case .authSessionStartFailed:
            return "Failed to start authentication session"
        case .noCallbackURL:
            return "No callback URL received"
        case .invalidCallbackURL:
            return "Invalid callback URL format"
        case .stateMismatch:
            return "Security state mismatch detected"
        case .oauthError(let message):
            return "OAuth error: \(message)"
        case .noAuthorizationCode:
            return "No authorization code received"
        case .tokenRequestEncodingFailed:
            return "Failed to encode token request"
        case .invalidResponse:
            return "Invalid response from server"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Keychain Helper

class Keychain {
    static let shared = Keychain()
    
    private init() {}
    
    func set(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain set error: \(status)")
        }
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Extension for Base64URL

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
