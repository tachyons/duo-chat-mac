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
    
    var body: some View {
        List(selection: $selectedThreadID) {
            Section {
                ForEach(chatService.threads) { thread in
                    ThreadRowView(thread: thread)
                        .tag(thread.id)
                }
            } header: {
                HStack {
                    Text("Conversations")
                    Spacer()
                    Button(action: chatService.startNewConversation) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
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
