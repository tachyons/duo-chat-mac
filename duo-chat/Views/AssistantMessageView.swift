//
//  AssistantMessageView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct AssistantMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.blue.gradient)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                MarkdownView(content: message.content)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 500, alignment: .leading)
        }
    }
}

#Preview {
//    let mockMessage = ChatMessage(
//        id: UUID().uuidString,
//        content: "Hello! I am your AI assistant. How can I help you today?",
//        role: .assistant,
//        timestamp: Date(),
//        threadId: "123"
//    )
//     AssistantMessageView(message: mockMessage)
//        .padding()
//        .previewLayout(.sizeThatFits)
}
