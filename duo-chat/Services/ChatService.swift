import SwiftUI
import Combine
import Foundation

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
    
    // MARK: - URL Context Properties
    @Published var customContextURL: String = ""
    @Published var detectedProjectID: String?
    @Published var detectedProjectPath: String? // Store namespace/project format
    @Published var detectedResourceID: String? // Store resource GID if available
    @Published var urlContextType: URLContextType = .homepage
    
    private var currentUser: GitLabUser?
    private weak var authService: AuthenticationService?
    private let webSocketManager = WebSocketManager()
    private var activeSubscriptionId: String?
    private var clientSubscriptionId: String = UUID().uuidString
    
    var onNewThreadCreated: ((String) -> Void)?
    
    private let session: URLSession
    
    init(authService: AuthenticationService? = nil) {
        self.authService = authService
        self.webSocketManager.authService = authService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        webSocketManager.onConnectionReady = { [weak self] in
            Task { @MainActor in
                await self?.setupGraphQLSubscriptions()
            }
        }
    }
    
    func setAuthService(authService: AuthenticationService) {
        self.authService = authService
        self.webSocketManager.authService = authService
        
        if authService.isAuthenticated {
            Task {
                await loadInitialData()
                await webSocketManager.connect()
            }
        }
    }
    
    deinit {
        Task.detached { [webSocketManager] in
            await webSocketManager.disconnect()
        }
    }
    
    func loadInitialData() async {
        await fetchCurrentUser()
        await loadThreads()
        await loadContextPresets()
        await loadSlashCommands()
        initializeDefaultContext()
    }

    func setCustomContextURL(_ url: String) {
        customContextURL = url
        analyzeURLContext(url)
    }
    
    func initializeDefaultContext() {
        // Set default context to GitLab homepage if no custom URL is set
        if customContextURL.isEmpty, let gitlabURL = authService?.currentGitLabURL {
            analyzeURLContext(gitlabURL)
        }
    }
    
    private func analyzeURLContext(_ url: String) {
        guard let gitlabURL = authService?.currentGitLabURL,
              !url.isEmpty else {
            urlContextType = .homepage
            detectedProjectID = nil
            detectedProjectPath = nil
            detectedResourceID = nil
            return
        }
        
        // Handle relative URLs or URLs that don't start with the GitLab base
        let fullURL: String
        if url.hasPrefix("http") {
            fullURL = url
        } else if url.hasPrefix("/") {
            fullURL = gitlabURL + url
        } else {
            fullURL = gitlabURL + "/" + url
        }
        
        // Ensure it's a GitLab URL
        guard fullURL.hasPrefix(gitlabURL) else {
            urlContextType = .unknown
            detectedProjectID = nil
            detectedProjectPath = nil
            detectedResourceID = nil
            return
        }
        
        // Remove the GitLab base URL to get the path
        let path = String(fullURL.dropFirst(gitlabURL.count))
        let projectPath = extractProjectIDFromPath(path)
        let (urlType, resourceInfo) = detectURLTypeAndResource(path)
        
        detectedProjectPath = projectPath
        detectedProjectID = projectPath // Keep this for display purposes
        detectedResourceID = resourceInfo?.resourceID
        urlContextType = urlType
        
        print("🔍 URL Analysis:")
        print("   Original: \(url)")
        print("   Full URL: \(fullURL)")
        print("   Path: \(path)")
        print("   Type: \(urlContextType.rawValue)")
        print("   Project Path: \(detectedProjectPath ?? "None")")
        print("   Resource ID: \(detectedResourceID ?? "None")")
    }
    
    private func extractProjectIDFromPath(_ path: String) -> String? {
        // GitLab URL patterns:
        // /namespace/project
        // /namespace/project/-/issues/123
        // /namespace/project/-/merge_requests/456
        // /namespace/project/-/pipelines/789
        // /namespace/project/-/tree/branch
        // /namespace/project/-/blob/branch/file
        // /namespace/project/-/wikis/page
        
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard components.count >= 2 else { return nil }
        
        // For GitLab, project path is typically namespace/project
        let namespace = components[0]
        let project = components[1]
        
        // Skip if it's a GitLab system path (admin, help, etc.)
        let systemPaths = ["admin", "help", "explore", "dashboard", "profile", "users", "groups", "api", "assets"]
        if systemPaths.contains(namespace.lowercased()) {
            return nil
        }
        
        // URL decode the components in case they contain special characters
        let decodedNamespace = namespace.removingPercentEncoding ?? namespace
        let decodedProject = project.removingPercentEncoding ?? project
        
        // Return the namespace/project path for now
        // This will be converted to GID format when needed
        return "\(decodedNamespace)/\(decodedProject)"
    }
    
    private func detectURLTypeAndResource(_ path: String) -> (URLContextType, ResourceInfo?) {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        // Root or dashboard
        if components.isEmpty || components == ["dashboard"] {
            return (.homepage, nil)
        }
        
        // Look for specific GitLab resource indicators
        if let issueMatch = path.range(of: #"/-/issues/(\d+)"#, options: .regularExpression) {
            let issueNumber = String(path[issueMatch]).components(separatedBy: "/").last ?? ""
            return (.issue, ResourceInfo(type: "Issue", number: issueNumber))
        } else if let mrMatch = path.range(of: #"/-/merge_requests/(\d+)"#, options: .regularExpression) {
            let mrNumber = String(path[mrMatch]).components(separatedBy: "/").last ?? ""
            return (.mergeRequest, ResourceInfo(type: "MergeRequest", number: mrNumber))
        } else if path.contains("/-/pipelines/") {
            if let pipelineMatch = path.range(of: #"/-/pipelines/(\d+)"#, options: .regularExpression) {
                let pipelineNumber = String(path[pipelineMatch]).components(separatedBy: "/").last ?? ""
                return (.pipeline, ResourceInfo(type: "Pipeline", number: pipelineNumber))
            }
            return (.pipeline, nil)
        } else if path.contains("/-/tree/") || path.contains("/-/blob/") || path.contains("/-/commits/") {
            return (.repository, nil)
        } else if path.contains("/-/wikis/") {
            return (.wiki, nil)
        } else if components.count >= 2 && !path.contains("/-/") {
            // Likely a project home page (namespace/project)
            return (.project, nil)
        }
        
        return (.unknown, nil)
    }
    
    // Helper struct for resource information
    private struct ResourceInfo {
        let type: String // "Issue", "MergeRequest", "Pipeline", etc.
        let number: String
        
        var resourceID: String {
            return "gid://gitlab/\(type)/\(number)"
        }
    }
    
    private func setupGraphQLSubscriptions() async {
        guard let currentUser = currentUser else {
            print("❌ Cannot setup subscriptions: No current user")
            return
        }
        
        print("🔧 Setting up GraphQL subscriptions...")
        
        if let existingSubscriptionId = activeSubscriptionId {
            await webSocketManager.unsubscribeFromGraphQL(subscriptionId: existingSubscriptionId)
        }
        
        let completionQuery = """
        subscription aiCompletionResponse($userId: UserID, $clientSubscriptionId: String, $aiAction: AiAction) {
          aiCompletionResponse(
            userId: $userId
            aiAction: $aiAction
            clientSubscriptionId: $clientSubscriptionId
          ) {
            id
            requestId
            content
            errors
            role
            threadId
            timestamp
            type
            chunkId
            extras {
              sources
              __typename
            }
            __typename
          }
        }
        """
        
        let completionVariables: [String: Any] = [
            "userId": currentUser.id,
            "aiAction": "CHAT",
            "clientSubscriptionId": clientSubscriptionId
        ]
        
        print("🔧 Subscription variables: \(completionVariables)")
        
        let subscriptionId = await webSocketManager.subscribeToGraphQL(
            query: completionQuery,
            variables: completionVariables,
            operationName: "aiCompletionResponse"
        ) { [weak self] data in
            Task { @MainActor in
                await self?.handleAIResponse(data: data)
            }
        }
        
        activeSubscriptionId = subscriptionId
        print("✅ GraphQL subscription setup complete with ID: \(subscriptionId)")
    }
    
    private func handleAIResponse(data: Data) async {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📨 Processing AI Response: \(json)")
                
                var responseData: [String: Any]?
                
                // Handle direct AI response format
                if let message = json["message"] as? [String: Any] {
                    // Check if this is the nested GraphQL subscription format
                    if let result = message["result"] as? [String: Any],
                       let data = result["data"] as? [String: Any],
                       let aiResponse = data["aiCompletionResponse"] {
                        
                        // ✅ Fix: Skip null responses entirely
                        if let nullResponse = aiResponse as? String, nullResponse == "<null>" {
                            print("📋 Received null AI response - subscription active, waiting for real data")
                            return
                        }
                        
                        // ✅ Fix: Only process if it's a dictionary (actual AI response)
                        if let aiResponseDict = aiResponse as? [String: Any] {
                            responseData = aiResponseDict
                            print("✅ Found AI response in nested message.result.data format")
                        }
                    }
                    // Check if message contains the AI response directly
                    else if let aiResponse = message["aiCompletionResponse"] as? [String: Any] {
                        responseData = aiResponse
                        print("✅ Found AI response in message format")
                    }
                }
                // Handle result format directly
                else if let result = json["result"] as? [String: Any],
                        let data = result["data"] as? [String: Any],
                        let aiResponse = data["aiCompletionResponse"] {
                    
                    // ✅ Fix: Skip null responses entirely
                    if let nullResponse = aiResponse as? String, nullResponse == "<null>" {
                        print("📋 Received null AI response - subscription active, waiting for real data")
                        return
                    }
                    
                    // ✅ Fix: Only process if it's a dictionary (actual AI response)
                    if let aiResponseDict = aiResponse as? [String: Any] {
                        responseData = aiResponseDict
                        print("✅ Found AI response in result.data format")
                    }
                }
                // Handle direct aiCompletionResponse format
                else if let aiResponse = json["aiCompletionResponse"] as? [String: Any] {
                    responseData = aiResponse
                    print("✅ Found AI response in direct format")
                }
                
                if let response = responseData {
                    await processAIResponse(response)
                } else {
                    print("📋 No valid AI response data found - likely a subscription confirmation or null response")
                }
            }
        } catch {
            print("❌ Error handling AI response: \(error)")
        }
    }

    private func processAIResponse(_ response: [String: Any]) async {
        // Validate we have the essential fields for a real AI message
        guard let role = response["role"] as? String,
              let threadId = response["threadId"] as? String,
              let content = response["content"] as? String,
              !content.isEmpty else {
            print("⚠️ Skipping invalid or empty AI response")
            print("⚠️ Role: \(response["role"] ?? "nil")")
            print("⚠️ ThreadId: \(response["threadId"] ?? "nil")")
            print("⚠️ Content: \(response["content"] ?? "nil")")
            return
        }
        
        let id = response["id"] as? String ?? UUID().uuidString
        let requestId = response["requestId"] as? String
        let timestamp = response["timestamp"] as? String
        let errors = response["errors"] as? [String]
        let type = response["type"] as? String
        
        // ✅ Fix: Handle chunkId properly - it can be Int or String
        let chunkId: String?
        if let chunkInt = response["chunkId"] as? Int {
            chunkId = String(chunkInt)
        } else if let chunkString = response["chunkId"] as? String {
            chunkId = chunkString == "<null>" ? nil : chunkString
        } else {
            chunkId = nil
        }
        
        print("✅ Processing valid AI response:")
        print("   Role: \(role)")
        print("   ThreadId: \(threadId)")
        print("   Content: \(content.prefix(50))...")
        print("   RequestId: \(requestId ?? "nil")")
        print("   ChunkId: \(chunkId ?? "nil")")
        print("   Type: \(type ?? "nil")")
        
        let messageRole = MessageRole(rawValue: role.lowercased()) ?? .assistant
        let messageTimestamp = parseDate(timestamp) ?? Date()
        
        if messages[threadId] == nil {
            messages[threadId] = []
        }
        
        // ✅ Fix: Properly detect streaming chunks
        let isStreamingChunk = chunkId != nil &&
                              chunkId != "<null>" &&
                              chunkId != "null" &&
                              !chunkId!.isEmpty &&
                              requestId != nil
        
        if isStreamingChunk {
            // This is a streaming chunk
            handleStreamingChunk(
                threadId: threadId,
                requestId: requestId!,
                content: content,
                role: messageRole,
                timestamp: messageTimestamp,
                chunkId: chunkId!,
                id: id,
                errors: errors
            )
        } else {
            // This is a complete message or final message
            let finalMessage = ChatMessage(
                id: id,
                content: content,
                role: messageRole,
                timestamp: messageTimestamp,
                threadId: threadId,
                requestId: requestId,
                chunkId: chunkId,
                errors: errors
            )
            
            // Check if this replaces an existing streaming message
            if let requestId = requestId,
               let index = messages[threadId]?.firstIndex(where: {
                   $0.requestId == requestId && $0.role == .assistant
               }) {
                messages[threadId]?[index] = finalMessage
                print("📝 Replaced streaming message with final complete message for thread \(threadId)")
            } else {
                messages[threadId]?.append(finalMessage)
                print("📝 Added complete message for thread \(threadId)")
            }
            
            isLoading = false
        }
        
        // Update thread list if this is a new thread
        if !threads.contains(where: { $0.id == threadId }) {
            await loadThreads()
        }
    }
    
    private func handleStreamingChunk(
        threadId: String,
        requestId: String?,
        content: String,
        role: MessageRole,
        timestamp: Date,
        chunkId: String,
        id: String,
        errors: [String]?
    ) {
        guard let requestId = requestId else {
            print("⚠️ Streaming chunk without requestId, treating as complete message")
            let newMessage = ChatMessage(
                id: id,
                content: content,
                role: role,
                timestamp: timestamp,
                threadId: threadId,
                requestId: requestId,
                chunkId: chunkId,
                errors: errors
            )
            messages[threadId]?.append(newMessage)
            return
        }
        
        // Find existing message with same requestId
        if let index = messages[threadId]?.firstIndex(where: {
            $0.requestId == requestId && $0.role == .assistant
        }) {
            // Update existing streaming message by concatenating content
            let existingMessage = messages[threadId]![index]
            let updatedMessage = ChatMessage(
                id: existingMessage.id,
                content: existingMessage.content + content,
                role: existingMessage.role,
                timestamp: existingMessage.timestamp,
                threadId: existingMessage.threadId,
                requestId: existingMessage.requestId,
                chunkId: chunkId, // Update to latest chunk ID
                errors: existingMessage.errors
            )
            messages[threadId]?[index] = updatedMessage
            print("📝 Updated streaming content for thread \(threadId), chunk \(chunkId)")
        } else {
            // Create new streaming message
            let newMessage = ChatMessage(
                id: id,
                content: content,
                role: role,
                timestamp: timestamp,
                threadId: threadId,
                requestId: requestId,
                chunkId: chunkId,
                errors: errors
            )
            messages[threadId]?.append(newMessage)
        }
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
                    title: thread.title ?? "Untitled",
                    conversationType: thread.conversationType,
                    createdAt: thread.createdAt,
                    lastUpdatedAt: thread.lastUpdatedAt
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
            
            messages[threadID] = threadMessages
            
            print("✅ Loaded \(threadMessages.count) messages for thread \(threadID)")
            isLoading = false
            
        } catch {
            self.error = error as? ChatServiceError ?? .loadMessagesFailed(error.localizedDescription)
            print("❌ Failed to load messages for thread \(threadID): \(error)")
        }
    }
    
    func deleteThread(_ threadID: String) async {
        do {
            let mutation = """
            mutation deleteConversationThread($input: DeleteConversationThreadInput!) {
                deleteConversationThread(input: $input) {
                    success
                    errors
                }
            }
            """
            
            let variables = [
                "input": [
                    "threadId": threadID
                ]
            ]
            
            let response: GraphQLResponse<DeleteThreadResponse> = try await executeGraphQLMutation(
                mutation: mutation,
                variables: variables
            )
            
            if let errors = response.data.deleteConversationThread.errors, !errors.isEmpty {
                throw ChatServiceError.deleteThreadFailed(errors.joined(separator: ", "))
            }
            
            if response.data.deleteConversationThread.success {
                threads.removeAll { $0.id == threadID }
                messages.removeValue(forKey: threadID)
                
                print("✅ Successfully deleted thread \(threadID)")
            } else {
                throw ChatServiceError.deleteThreadFailed("Delete operation returned false")
            }
            
        } catch {
            self.error = error as? ChatServiceError ?? .deleteThreadFailed(error.localizedDescription)
            print("❌ Failed to delete thread \(threadID): \(error)")
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
            
            var input: [String: Any] = [
                "chat": [
                    "content": content,
                    "resourceId": currentUser.id,
                ],
                "conversationType": "DUO_CHAT",
                "clientSubscriptionId": clientSubscriptionId
            ]
            
            if let threadID = threadID {
                input["threadId"] = threadID
            }
            
            let variables: [String: Any] = ["input": input]
            
            let response: GraphQLResponse<AiActionResponse> = try await executeGraphQLMutation(
                mutation: mutation,
                variables: variables
            )
            
            if let errors = response.data.aiAction.errors, !errors.isEmpty {
                throw ChatServiceError.sendMessageFailed(errors.joined(separator: ", "))
            }
            
            let actualThreadID = response.data.aiAction.threadId ?? targetThreadID
            
            if threadID == nil {
                if let tempMessages = messages[targetThreadID] {
                    messages[actualThreadID] = tempMessages
                    messages.removeValue(forKey: targetThreadID)
                }
                
                let newThread = ChatThread(
                    id: actualThreadID,
                    title: String(content.prefix(50)),
                    conversationType: "DUO_CHAT",
                    createdAt: DateFormatter().string(from: Date()),
                    lastUpdatedAt: DateFormatter().string(from: Date())
                )
                threads.insert(newThread, at: 0)
                
                onNewThreadCreated?(actualThreadID)
            }
            
            print("✅ Message sent successfully, waiting for AI response via WebSocket")
            
        } catch {
            self.error = error as? ChatServiceError ?? .sendMessageFailed(error.localizedDescription)
            print("❌ Failed to send message: \(error)")
            isLoading = false
        }
    }
    
    func startNewConversation() {
        let newClientSubscriptionId = UUID().uuidString
        clientSubscriptionId = newClientSubscriptionId
        
        print("🆕 Starting new conversation with clientSubscriptionId: \(clientSubscriptionId)")
        
        Task {
            await setupGraphQLSubscriptions()
        }
    }
    
    func loadContextPresets() async {
        do {
            let query = """
            query getAiChatContextPresets($resourceId: AiModelID, $projectId: ProjectID, $url: String, $questionCount: Int) {
                aiChatContextPresets(
                    resourceId: $resourceId,
                    projectId: $projectId,
                    url: $url, 
                    questionCount: $questionCount
                ) {
                    questions
                    __typename
                }
            }
            """
            
            var variables: [String: Any] = [
                "url": getCurrentPageURL(),
                "questionCount": 4,
                "projectId": "gid://gitlab/Project/278964" // Hard coded for now
            ]
            
            // Add project ID in GID format if available
            if let projectPath = detectedProjectPath {
                // For now, we'll need to fetch the numeric project ID
                // This would require a separate GraphQL query to resolve the project path to numeric ID
                // For demonstration, we'll use the project path format
                print("⚠️ Project path detected: \(projectPath)")
                print("⚠️ To get proper GID format, would need to resolve project path to numeric ID")
                
                // We would need to implement a method to convert project path to numeric ID
//                 variables["projectId"] = 
            }
            
            // Add resource ID if available (for specific resources like MRs, Issues)
            if let resourceID = detectedResourceID {
                variables["resourceId"] = resourceID
                print("✅ Using resource ID: \(resourceID)")
            }
            
            print("🔧 Context presets query variables: \(variables)")
            
            let response: GraphQLResponse<ContextPresetsResponse> = try await executeGraphQLQuery(
                query: query,
                variables: variables
            )
            
            if let questions = response.data.aiChatContextPresets?.questions {
                contextPresets = questions.enumerated().map { index, question in
                    ContextPreset(
                        prompt: question,
                        category: "context"
                    )
                }
                print("✅ Loaded \(contextPresets.count) context presets")
            } else {
                contextPresets = []
                print("⚠️ No context presets returned from API")
            }
            
        } catch {
            print("⚠️ Failed to load context presets: \(error)")
            contextPresets = []
        }
    }
    
    // MARK: - Project Resolution Helper
    
    /// Resolves a project path (namespace/project) to its numeric ID
    /// This would be needed to create proper GID format
    private func resolveProjectPathToNumericID(_ projectPath: String) async -> String? {
        do {
            let query = """
            query($fullPath: ID!) {
                project(fullPath: $fullPath) {
                    id
                }
            }
            """
            
            let variables = ["fullPath": projectPath]
            
            let response: GraphQLResponse<ProjectResponse> = try await executeGraphQLQuery(
                query: query,
                variables: variables
            )
            
            return response.data.project?.id
            
        } catch {
            print("❌ Failed to resolve project path \(projectPath): \(error)")
            return nil
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
            print("⚠️ Failed to load slash commands: \(error)")
            slashCommands = []
        }
    }
    
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
                await authService.refreshTokenIfNeeded()
                throw ChatServiceError.authenticationExpired
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                throw ChatServiceError.httpError(httpResponse.statusCode, responseBody)
            }
            
            let graphqlResponse = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
            
            if let errors = graphqlResponse.errors, !errors.isEmpty {
                let errorMessages = errors.map { $0.message }.joined(separator: ", ")
                
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
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return simpleDateFormatter.date(from: dateString)
    }
    
    private func getCurrentPageURL() -> String {
        // Return custom URL if set, otherwise default to GitLab homepage
        if !customContextURL.isEmpty {
            return customContextURL
        }
        return authService?.currentGitLabURL ?? "https://gitlab.com"
    }
    
    private func extractProjectIdFromCurrentContext() -> String? {
        // Return detected project path if available
        // Note: This should be converted to GID format for the API
        return detectedProjectPath
    }
}

// MARK: - URL Context Type Enum

enum URLContextType: String, CaseIterable {
    case homepage = "Homepage"
    case project = "Project"
    case issue = "Issue"
    case mergeRequest = "Merge Request"
    case pipeline = "Pipeline"
    case repository = "Repository"
    case wiki = "Wiki"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .homepage: return "house"
        case .project: return "folder"
        case .issue: return "exclamationmark.circle"
        case .mergeRequest: return "arrow.triangle.merge"
        case .pipeline: return "pipe.and.drop"
        case .repository: return "doc.text"
        case .wiki: return "book"
        case .unknown: return "questionmark.circle"
        }
    }
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
    case deleteThreadFailed(String)
    case webSocketConnectionFailed(String)
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
        case .deleteThreadFailed(let message):
            return "Failed to delete conversation: \(message)"
        case .webSocketConnectionFailed(let message):
            return "WebSocket connection failed: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}


struct ProjectResponse: Codable {
    let project: ProjectInfo?
}

struct ProjectInfo: Codable {
    let id: String
}
