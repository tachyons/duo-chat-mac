//
//  ChatHeaderView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct ChatHeaderView: View {
    let thread: ChatThread
    @EnvironmentObject var chatService: ChatService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.headline)
                
//                Text("Updated \(thread.createdAt, style: .relative)")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                StatusBadge(
                    title: chatService.duoChatEnabled ? "Duo Chat Enabled" : "Duo Chat Disabled",
                    color: chatService.duoChatEnabled ? .green : .red
                )
                
                if chatService.tokenExpiryWarning {
                    StatusBadge(title: "Token expires soon", color: .orange)
                }
            }
        }
    }
}
