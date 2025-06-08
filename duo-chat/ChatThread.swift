//
//  ChatThread.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct ChatThread: Identifiable, Codable {
    let id: String
    let title: String
    let conversationType: String
    let createdAt: String
    let lastUpdatedAt: String
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    let threadId: String?
    let requestId: String?
    let chunkId: String?
    let errors: [String]?
}

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
}

struct ContextPreset: Codable {
    let prompt: String
    let category: String
}

struct SlashCommand: Codable {
    let name: String
    let description: String
}
