import SwiftUI
import Combine
import Foundation

// MARK: - Chat Service
@MainActor
class ChatService: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var messages: [String: [ChatMessage]] = [:]
    @Published var isLoading = false
    @Published var duoChatEnabled = false
    @Published var contextPresets: [ContextPreset] = []
    @Published var slashCommands: [SlashCommand] = []
    @Published var tokenExpiryWarning = false
    @Published var error: ChatServiceError?
    
    private var currentUser: GitLabUser?
    private weak var authService: AuthenticationService?
    var onNewThreadCreated: ((String) -> Void)?

    
    // Network configuration
    private let session: URLSession
    
    init(authService: AuthenticationService? = nil) {
        self.authService = authService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func setAuthService(authService: AuthenticationService) {
            self.authService = authService
            
            // Automatically load initial data when auth service is set and user is authenticated
            if authService.isAuthenticated {
                Task {
                    await loadInitialData()
                }
            }
        }
        
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
            await fetchCurrentUser()
            await loadThreads()
            await loadContextPresets()
            await loadSlashCommands()
        
    }
    
    func loadThreads() async {
        do {
            let query = """
            query {
                aiConversationThreads(conversationType: DUO_CHAT) {
                    nodes {
                        id
                        conversationType
                        createdAt
                        title,
                        lastUpdatedAt
                    }
                }
            }
            """
            
            let response: GraphQLResponse<ThreadsResponse> = try await executeGraphQLQuery(query: query)
            
            
            self.threads = response.data.aiConversationThreads.nodes.map { thread in
                ChatThread(
                    id: thread.id,
                    title: thread.title ??  "Untitled",
                    conversationType: thread.conversationType,
                    createdAt: thread.createdAt,
                    lastUpdatedAt: thread.lastUpdatedAt,
                )
            }
            
            print("✅ Loaded \(threads.count) conversation threads")
            
        } catch {
            debugPrint(error)
            self.error = error as? ChatServiceError ?? .loadThreadsFailed(error.localizedDescription)
            print("❌ Failed to load threads: \(error)")
        }
    }
    
    func loadMessages(for threadID: String) async {
        do {
            let query = """
            query($threadId: AiConversationThreadID!) {
                aiMessages(threadId: $threadId) {
                    nodes {
                        id
                        requestId
                        content
                        role
                        timestamp
                        chunkId
                        errors
                    }
                }
            }
            """
            
            let variables = ["threadId": threadID]
            let response: GraphQLResponse<MessagesResponse> = try await executeGraphQLQuery(
                query: query,
                variables: variables
            )
            
            let threadMessages = response.data.aiMessages.nodes.map { msg in
                ChatMessage(
                    id: msg.id,
                    content: msg.content,
                    role: MessageRole(rawValue: msg.role.lowercased()) ?? .assistant,
                    timestamp: parseDate(msg.timestamp) ?? Date(),
                    threadId: threadID,
                    requestId: msg.requestId,
                    chunkId: msg.chunkId,
                    errors: msg.errors
                )
            }.sorted { $0.timestamp < $1.timestamp }
            
            // Update messages for this thread
            messages[threadID] = threadMessages
            
            print("✅ Loaded \(threadMessages.count) messages for thread \(threadID)")
            
        } catch {
            self.error = error as? ChatServiceError ?? .loadMessagesFailed(error.localizedDescription)
            print("❌ Failed to load messages for thread \(threadID): \(error)")
        }
    }
    
    func sendMessage(content: String, threadID: String?) async {
        guard duoChatEnabled else {
            error = .duoChatNotEnabled
            return
        }
        
        guard let currentUser = currentUser else {
            error = .userNotFound
            return
        }
        
        isLoading = true
        error = nil
        
        // Add user message to UI immediately
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            content: content,
            role: .user,
            timestamp: Date(),
            threadId: threadID,
            requestId: nil,
            chunkId: nil,
            errors: nil
        )
        
        let targetThreadID = threadID ?? "temp-\(UUID().uuidString)"
        if messages[targetThreadID] == nil {
            messages[targetThreadID] = []
        }
        messages[targetThreadID]?.append(userMessage)
        
        do {
            let mutation = """
            mutation($input: AiActionInput!) {
                aiAction(input: $input) {
                    requestId
                    errors
                    threadId
                }
            }
            """
            
            let input: [String: Any] = [
                "chat": [
                    "content": content,
                    "resourceId": currentUser.id
                ],
                "conversationType": "DUO_CHAT"
            ]
            
            // Add threadId if we have one
            var variables: [String: Any] = ["input": input]
            if let threadID = threadID {
                variables["input"] = (variables["input"] as! [String: Any]).merging(["threadId": threadID]) { _, new in new }
            }
            
            let response: GraphQLResponse<AiActionResponse> = try await executeGraphQLMutation(
                mutation: mutation,
                variables: variables
            )
            
            if let errors = response.data.aiAction.errors, !errors.isEmpty {
                throw ChatServiceError.sendMessageFailed(errors.joined(separator: ", "))
            }
            
            let actualThreadID = response.data.aiAction.threadId ?? targetThreadID
            let requestId = response.data.aiAction.requestId
            
            // Update thread ID if this was a new conversation
            if threadID == nil {
                // Move messages from temp thread to actual thread
                if let tempMessages = messages[targetThreadID] {
                    messages[actualThreadID] = tempMessages
                    messages.removeValue(forKey: targetThreadID)
                }
                
                // Add new thread to list
                let newThread = ChatThread(
                    id: actualThreadID,
                    title: String(content.prefix(50)),
                    conversationType: "DUO_CHAT",
                    createdAt: DateFormatter().string(from: Date()),
                    lastUpdatedAt: DateFormatter().string(from: Date())
                )
                threads.insert(newThread, at: 0)
                
                // Notify that a new thread was created
                onNewThreadCreated?(actualThreadID)
            }
            
            // Poll for AI response
            await pollForResponse(requestId: requestId, threadID: actualThreadID)
            
        } catch {
            self.error = error as? ChatServiceError ?? .sendMessageFailed(error.localizedDescription)
            print("❌ Failed to send message: \(error)")
        }
        
        isLoading = false
    }
    
    func startNewConversation() {
        // This will be handled when the first message is sent
        print("🆕 Starting new conversation")
    }
    
    func loadContextPresets() async {
        do {
            let query = """
            query($url: String!, $resourceId: AiModelID, $questionCount: Int, $projectId: ProjectID) {
                aiChatContextPresets(
                    url: $url, 
                    resourceId: $resourceId, 
                    questionCount: $questionCount,
                    projectId: $projectId
                ) {
                    questions
                }
            }
            """
            
            let variables: [String: Any?] = [
                "url": getCurrentPageURL(),
                "resourceId": currentUser?.id,
                "questionCount": 5,
                "projectId": extractProjectIdFromCurrentContext()
            ]
            
            let response: GraphQLResponse<ContextPresetsResponse> = try await executeGraphQLQuery(
                query: query,
                variables: variables.compactMapValues { $0 }
            )
            
            if let questions = response.data.aiChatContextPresets?.questions {
                contextPresets = questions.enumerated().map { index, question in
                    ContextPreset(
                        prompt: question,
                        category: "context"
                    )
                }
            }
            
            print("✅ Loaded \(contextPresets.count) context presets")
            
        } catch {
            // Context presets are optional, so we don't set error state
            print("⚠️ Failed to load context presets: \(error)")
            contextPresets = []
        }
    }
    
    func loadSlashCommands() async {
        do {
            let query = """
            query($url: String!) {
                aiSlashCommands(url: $url) {
                    name
                    description
                }
            }
            """
            
            let variables = ["url": getCurrentPageURL()]
            let response: GraphQLResponse<SlashCommandsResponse> = try await executeGraphQLQuery(
                query: query,
                variables: variables
            )
            
            slashCommands = response.data.aiSlashCommands ?? []
            
            print("✅ Loaded \(slashCommands.count) slash commands")
            
        } catch {
            // Slash commands are optional, so we don't set error state
            print("⚠️ Failed to load slash commands: \(error)")
            slashCommands = []
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchCurrentUser() async {
        do {
            let query = """
            query {
                currentUser {
                    id
                    username
                    name
                    duoChatAvailable
                    duoChatAvailableFeatures
                }
            }
            """
            
            let response: GraphQLResponse<CurrentUserResponse> = try await executeGraphQLQuery(query: query)
            
            if let user = response.data.currentUser {
                currentUser = user
                duoChatEnabled = user.duoChatAvailable
                
                print("✅ Current user: \(user.username) (Duo Chat: \(user.duoChatAvailable))")
            } else {
                throw ChatServiceError.userNotFound
            }
            
        } catch {
            self.error = error as? ChatServiceError ?? .fetchUserFailed(error.localizedDescription)
            duoChatEnabled = false
            
            print("❌ Failed to fetch current user: \(error)")
        }
    }
    
    private func pollForResponse(requestId: String, threadID: String) async {
        let maxAttempts = 30
        let pollInterval: TimeInterval = 1.0
        
        for attempt in 1...maxAttempts {
            do {
                // Small delay before polling
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                
                await loadMessages(for: threadID)
                
                // Check if we have a response for this request
                if let threadMessages = messages[threadID],
                   threadMessages.contains(where: { $0.requestId == requestId && $0.role == .assistant }) {
                    print("✅ AI response received after \(attempt) attempts")
                    return
                }
                
                print("🔄 Polling attempt \(attempt)/\(maxAttempts) for request \(requestId)")
                
            } catch {
                print("⚠️ Polling error (attempt \(attempt)): \(error)")
                if attempt == maxAttempts {
                    self.error = .pollingTimeout
                }
            }
        }
        
        print("❌ Polling timeout after \(maxAttempts) attempts")
        error = .pollingTimeout
    }
    
    private func executeGraphQLQuery<T: Codable>(
        query: String,
        variables: [String: Any] = [:]
    ) async throws -> GraphQLResponse<T> {
        return try await executeGraphQL(query: query, variables: variables, operationType: "query")
    }
    
    private func executeGraphQLMutation<T: Codable>(
        mutation: String,
        variables: [String: Any] = [:]
    ) async throws -> GraphQLResponse<T> {
        return try await executeGraphQL(query: mutation, variables: variables, operationType: "mutation")
    }
    
    private func executeGraphQL<T: Codable>(
        query: String,
        variables: [String: Any] = [:],
        operationType: String
    ) async throws -> GraphQLResponse<T> {
        
        guard let authService = authService,
              let accessToken = authService.currentAccessToken,
              let gitlabURL = authService.currentGitLabURL else {
            throw ChatServiceError.notAuthenticated
        }
        
      
        guard let url = URL(string: "\(gitlabURL)/api/graphql") else {
            throw ChatServiceError.invalidURL
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("GitLabDuoChat/1.0", forHTTPHeaderField: "User-Agent")
        
        let requestBody: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            print("📤 GraphQL \(operationType): \(query.prefix(100))...")
            if !variables.isEmpty {
                print("📝 Variables: \(variables)")
            }
            
        } catch {
            throw ChatServiceError.requestEncodingFailed
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatServiceError.invalidResponse
            }
            
            print("📊 GraphQL Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                // Token might be expired, try to refresh
                await authService.refreshTokenIfNeeded()
                throw ChatServiceError.authenticationExpired
            }
                        
            
            guard httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                throw ChatServiceError.httpError(httpResponse.statusCode, responseBody)
            }
            
            // Parse GraphQL response
            let graphqlResponse = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
            
            // Check for GraphQL errors
            if let errors = graphqlResponse.errors, !errors.isEmpty {
                let errorMessages = errors.map { $0.message }.joined(separator: ", ")
                
                // Check for authentication errors
                if errors.contains(where: { $0.message.contains("token") || $0.message.contains("unauthorized") }) {
                    throw ChatServiceError.authenticationExpired
                }
                
                throw ChatServiceError.graphqlError(errorMessages)
            }
            
            print("✅ GraphQL \(operationType) successful")
            return graphqlResponse
            
        } catch let error as ChatServiceError {
            throw error
        } catch let urlError as URLError {
            throw ChatServiceError.networkError(urlError.localizedDescription)
        } catch {
            if error is DecodingError {
                debugPrint(error)
                throw ChatServiceError.decodingError(error.localizedDescription)
            }
            throw ChatServiceError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateThreadTitle(from id: String) -> String {
        let components = id.split(separator: "/")
        if let lastComponent = components.last {
            return "Conversation \(lastComponent)"
        }
        return "Conversation \(id.suffix(8))"
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        
        
        return nil
    }
    
    private func getCurrentPageURL() -> String {
        // In a real app, this might come from the current context
        // For now, return a generic URL
        return authService?.currentGitLabURL ?? "https://gitlab.com"
    }
    
    private func extractProjectIdFromCurrentContext() -> String? {
        // This would extract project ID from current context
        // Implementation depends on how the app navigates GitLab projects
        return nil
    }
}

// MARK: - GraphQL Response Models

struct GraphQLResponse<T: Codable>: Codable {
    let data: T
    let errors: [GraphQLError]?
}

struct GraphQLError: Codable {
    let message: String
    let locations: [Location]?
    let path: [String]?
    
    struct Location: Codable {
        let line: Int
        let column: Int
    }
}

// MARK: - API Response Models

struct ThreadsResponse: Codable {
    let aiConversationThreads: ThreadsContainer
    
    struct ThreadsContainer: Codable {
        let nodes: [ThreadNode]
    }
    
    struct ThreadNode: Codable {
        let id: String
        let conversationType: String
        let createdAt: String
        let title: String?
        let lastUpdatedAt: String
    }
}

struct MessagesResponse: Codable {
    let aiMessages: MessagesContainer
    
    struct MessagesContainer: Codable {
        let nodes: [MessageNode]
    }
    
    struct MessageNode: Codable {
        let id: String
        let requestId: String?
        let content: String
        let role: String
        let timestamp: String?
        let chunkId: String?
        let errors: [String]?
    }
}

struct CurrentUserResponse: Codable {
    let currentUser: GitLabUser?
}

struct GitLabUser: Codable {
    let id: String
    let username: String
    let name: String
    let duoChatAvailable: Bool
    let duoChatAvailableFeatures: [String]?
}

struct AiActionResponse: Codable {
    let aiAction: AiAction
    
    struct AiAction: Codable {
        let requestId: String
        let errors: [String]?
        let threadId: String?
    }
}

struct ContextPresetsResponse: Codable {
    let aiChatContextPresets: ContextPresetsContainer?
    
    struct ContextPresetsContainer: Codable {
        let questions: [String]?
    }
}

struct SlashCommandsResponse: Codable {
    let aiSlashCommands: [SlashCommand]?
}

// MARK: - Error Types

enum ChatServiceError: LocalizedError {
    case notAuthenticated
    case authenticationExpired
    case userNotFound
    case duoChatNotEnabled
    case invalidURL
    case requestEncodingFailed
    case invalidResponse
    case networkError(String)
    case httpError(Int, String)
    case graphqlError(String)
    case decodingError(String)
    case fetchUserFailed(String)
    case loadThreadsFailed(String)
    case loadMessagesFailed(String)
    case sendMessageFailed(String)
    case pollingTimeout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in again."
        case .authenticationExpired:
            return "Authentication expired. Please sign in again."
        case .userNotFound:
            return "User information not found."
        case .duoChatNotEnabled:
            return "Duo Chat is not enabled for your account."
        case .invalidURL:
            return "Invalid GitLab URL configuration."
        case .requestEncodingFailed:
            return "Failed to encode request data."
        case .invalidResponse:
            return "Invalid response from server."
        case .networkError(let message):
            return "Network error: \(message)"
        case .httpError(let code, let body):
            return "HTTP error \(code): \(body)"
        case .graphqlError(let message):
            return "GraphQL error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .fetchUserFailed(let message):
            return "Failed to fetch user: \(message)"
        case .loadThreadsFailed(let message):
            return "Failed to load conversations: \(message)"
        case .loadMessagesFailed(let message):
            return "Failed to load messages: \(message)"
        case .sendMessageFailed(let message):
            return "Failed to send message: \(message)"
        case .pollingTimeout:
            return "Timeout waiting for AI response."
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
