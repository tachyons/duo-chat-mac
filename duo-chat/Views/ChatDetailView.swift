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
                            WelcomeView()
                        }
                        else {
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
                .onChange(of: chatService.isLoading) { _, isLoading in
                    // Scroll to bottom when loading starts/stops
                    if !isLoading, let lastMessage = currentMessages.last {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Enhanced Input Area with URL Context
            ChatInputView(
                messageText: $messageText,
                showingSuggestions: $showingSuggestions,
                showingCommands: $showingCommands,
                threadID: threadID
            )
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
        .task(id: threadID) {
            // Load messages when thread changes
            if let threadID = threadID {
                await chatService.loadMessages(for: threadID)
            }
        }
        .onAppear {
            // Initialize context when view appears
            chatService.initializeDefaultContext()
        }
    }
}

#Preview {
    let chatService = ChatService()
//    chatService.duoChatEnabled = true
//    chatService.threads = [
//        ChatThread(id: "1", title: "Test Thread", conversationType: "DUO_CHAT", createdAt: "", lastUpdatedAt: "")
//    ]
//    chatService.messages["1"] = [
//        ChatMessage(id: "msg1", content: "Hello from AI", role: .assistant, timestamp: Date(), threadId: "1", requestId: nil, chunkId: nil, errors: nil),
//        ChatMessage(id: "msg2", content: "Hello from User", role: .user, timestamp: Date(), threadId: "1", requestId: nil, chunkId: nil, errors: nil)
//    ]

    ChatDetailView(
        threadID: "1",
        messageText: .constant(""),
        showingSuggestions: .constant(false),
        showingCommands: .constant(false)
    )
    .environmentObject(chatService)
}
