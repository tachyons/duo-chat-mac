//
//  UserMessageView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct UserMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: 400, alignment: .trailing)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let mockMessage = ChatMessage(
        id: UUID().uuidString,
        content: "This is a user message example.",
        role: .user,
        timestamp: Date(),
        threadId: "123",
        requestId: nil,
        chunkId: nil,
        errors: nil
    )
    UserMessageView(message: mockMessage)
        .padding()
}
