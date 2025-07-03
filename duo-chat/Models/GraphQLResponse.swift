//
//  GraphQLResponse.swift
//  duo-chat
//
//  Created by Aboobacker MK on 29/06/25.
//


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

struct DeleteThreadResponse: Codable {
    let deleteConversationThread: DeleteConversationThreadResult
    
    struct DeleteConversationThreadResult: Codable {
        let success: Bool
        let errors: [String]?
    }
}

