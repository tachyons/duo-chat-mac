//
//  MessageView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                UserMessageView(message: message)
            } else {
                AssistantMessageView(message: message)
                Spacer()
            }
        }
    }
}

#Preview("User Message", traits: .sizeThatFitsLayout) {
    let userMessage = ChatMessage(
        id: UUID().uuidString,
        content: "Can you explain the concept of SwiftUI's @State property wrapper?",
        role: .user,
        timestamp: Date(),
        threadId: "1",
        requestId: nil,
        chunkId: nil,
        errors: nil
    )
    MessageView(message: userMessage)
        .padding()
}

#Preview("Assistant Message", traits: .sizeThatFitsLayout) {
    let assistantMessage = ChatMessage(
        id: UUID().uuidString,
        content: "@State is a property wrapper in SwiftUI that allows you to create a source of truth for value types within a view. When the value of a @State property changes, SwiftUI automatically re-renders the view and any of its subviews that depend on that property.",
        role: .assistant,
        timestamp: Date(),
        threadId: "1",
        requestId: nil,
        chunkId: nil,
        errors: nil
    )
    AssistantMessageView(message: assistantMessage)
        .padding()
}
