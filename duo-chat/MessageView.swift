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


