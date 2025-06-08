//
//  ChatDetailView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct ChatDetailView: View {
    let threadID: String?
    @Binding var messageText: String
    @Binding var showingSuggestions: Bool
    @Binding var showingCommands: Bool
    @EnvironmentObject var chatService: ChatService
    @FocusState private var isTextFieldFocused: Bool
    
    var currentMessages: [ChatMessage] {
        guard let threadID = threadID else { return [] }
        return chatService.messages[threadID] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let threadID = threadID,
               let thread = chatService.threads.first(where: { $0.id == threadID }) {
                ChatHeaderView(thread: thread)
                    .padding()
                    .background(.regularMaterial)
            }
            
            // Messages or Welcome State
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if threadID == nil {
                            // Welcome state for new conversation
                            VStack(spacing: 20) {
                                Image(systemName: "message.badge.waveform")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    Text("Start a New Conversation")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Ask Duo Chat anything to begin")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            if !chatService.duoChatEnabled {
                                DuoChatDisabledView()
                                    .padding()
                            }
                            
                            ForEach(currentMessages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if chatService.isLoading {
                                LoadingMessageView()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: currentMessages.count) { _, _ in
                    if let lastMessage = currentMessages.last {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Area
            ChatInputView(
                messageText: $messageText,
                showingSuggestions: $showingSuggestions,
                showingCommands: $showingCommands,
                threadID: threadID
            )
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}
