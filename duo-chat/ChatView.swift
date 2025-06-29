    //
//  ChatView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var chatService: ChatService
    @State private var selectedThreadID: String?
    @State private var messageText = ""
    @State private var showingSuggestions = false
    @State private var showingCommands = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedThreadID: $selectedThreadID)
        } detail: {
            // Main Chat Area
            ChatDetailView(
                threadID: selectedThreadID,
                messageText: $messageText,
                showingSuggestions: $showingSuggestions,
                showingCommands: $showingCommands
            )
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    chatService.startNewConversation()
                    selectedThreadID = nil
                    messageText = ""
                    showingSuggestions = false
                    showingCommands = false
                }) {
                    Image(systemName: "plus.message")
                }
                .help("New Conversation")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Sign Out", action: authService.signOut)
                    Divider()
                    Button("Refresh Threads") {
                        Task {
                            await chatService.loadThreads()
                        }
                    }
                    Button("About") { /* About action */  }
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .task {
            // Only load initial data if authenticated
            if authService.isAuthenticated {
                await chatService.loadInitialData()
            }
        }
        .onAppear {
            // Set up callback for new thread creation
            chatService.onNewThreadCreated = { newThreadID in
                selectedThreadID = newThreadID
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // User just authenticated, load data
                Task {
                    await chatService.loadInitialData()
                }
            } else {
                // User signed out, clear state
                selectedThreadID = nil
                messageText = ""
                showingSuggestions = false
                showingCommands = false
            }
        }
    }
}

#Preview(){
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)

    ChatView()
        .environmentObject(authService)
        .environmentObject(chatService)
}
