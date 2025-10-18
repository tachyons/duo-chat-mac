//
//  ChatHeaderView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

import SwiftUI

struct ChatHeaderView: View {
    let thread: ChatThread
    @EnvironmentObject var chatService: ChatService
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let lastUpdatedDate = parseLastUpdatedDate() {
                    Text(lastUpdatedDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                
                // Delete thread button
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete Conversation")
            }
        }
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await chatService.deleteThread(thread.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }
    
    private func parseLastUpdatedDate() -> Date? {
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        simpleDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return simpleDateFormatter.date(from: thread.lastUpdatedAt)
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
}
#Preview{
    // Create a mock ChatThread
    let mockThread = ChatThread(
        id: "1",
        title: "Mock Chat Thread Title",
        conversationType: "DUO_CHAT",
        createdAt: "2025-10-18T10:00:00Z",
        lastUpdatedAt: "2025-10-18T10:30:00Z"
    )
    
    // Create a mock ChatService
    let mockChatService = ChatService()
    mockChatService.duoChatEnabled = true
    mockChatService.tokenExpiryWarning = false
    
    return ChatHeaderView(thread: mockThread)
        .environmentObject(mockChatService)
        .padding()
      
}
