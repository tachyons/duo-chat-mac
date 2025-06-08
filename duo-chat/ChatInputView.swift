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
                
                // Helper text
                Text("⌘⏎ Send • ⇧⏎ New line")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Message Input
            HStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text(chatService.duoChatEnabled ?
                             "Ask Duo Chat anything..." :
                             "Duo Chat is not available for your account")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $messageText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 30, maxHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .focused($isTextFieldFocused)
                        .disabled(!chatService.duoChatEnabled)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSControlTextDidEndEditingNotification"))) { notification in
                            // Handle text editing notifications if needed
                        }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                Button(action: sendMessage) {
                    Image(systemName: chatService.isLoading ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
                .keyboardShortcut(.return, modifiers: .command)
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
