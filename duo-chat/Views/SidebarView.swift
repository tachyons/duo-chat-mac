//
//  SidebarView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var chatService: ChatService
    @Binding var selectedThreadID: String?
    @State private var searchText = ""

    var filteredThreads: [ChatThread] {
        if searchText.isEmpty {
            return chatService.threads
        } else {
            return chatService.threads.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Conversations", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 5)

            List(selection: $selectedThreadID) {
                Section {
                    ForEach(filteredThreads) { thread in
                        ThreadRowView(thread: thread)
                            .tag(thread.id)
                    }
                } header: {
                    HStack {
                        Text("Conversations")
                        Spacer()
                        Button(action: {
                            selectedThreadID = nil
                            chatService.startNewConversation()
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .help("New Conversation")
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("Duo Chat")
        .onChange(of: selectedThreadID) { _, newValue in
            if let threadID = newValue {
                Task {
                    await chatService.loadMessages(for: threadID)
                }
            }
        }
    }
}

#Preview("Sidebar") {
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)
    chatService.duoChatEnabled = true
    chatService.threads = [
        ChatThread(id: "1", title: "First Conversation", conversationType: "DUO_CHAT", createdAt: "2025-10-18T10:00:00Z", lastUpdatedAt: "2025-10-18T10:05:00Z"),
        ChatThread(id: "2", title: "Second Conversation", conversationType: "DUO_CHAT", createdAt: "2025-10-18T11:00:00Z", lastUpdatedAt: "2025-10-18T11:05:00Z"),
        ChatThread(id: "3", title: "Another Chat", conversationType: "DUO_CHAT", createdAt: "2025-10-18T12:00:00Z", lastUpdatedAt: "2025-10-18T12:05:00Z")
    ]
    
    return SidebarView(selectedThreadID: .constant("1"))
        .environmentObject(chatService)
        .frame(width: 300)
}
