//
//  ChatInputView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var showingSuggestions: Bool
    @Binding var showingCommands: Bool
    let threadID: String?
    @EnvironmentObject var chatService: ChatService
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Suggestions and Commands
            if showingSuggestions || showingCommands {
                SuggestionsView(
                    showingSuggestions: $showingSuggestions,
                    showingCommands: $showingCommands,
                    messageText: $messageText
                )
            }
            
            // Helper Buttons
            HStack(spacing: 8) {
                Button(action: { showingSuggestions.toggle() }) {
                    Label("Suggestions", systemImage: "lightbulb")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: { showingCommands.toggle() }) {
                    Label("Commands", systemImage: "terminal")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField(
                    chatService.duoChatEnabled ? 
                    "Ask Duo Chat anything..." : 
                    "Duo Chat is not available for your account",
                    text: $messageText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isTextFieldFocused)
                .disabled(!chatService.duoChatEnabled)
                .onSubmit {
                    sendMessage()
                }
                
                Button(action: sendMessage) {
                    Image(systemName: chatService.isLoading ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
            }
        }
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !chatService.isLoading && 
        chatService.duoChatEnabled
    }
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await chatService.sendMessage(content: content, threadID: threadID)
        }
    }
}
