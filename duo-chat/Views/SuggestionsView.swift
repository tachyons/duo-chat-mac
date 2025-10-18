//
//  SuggestionsView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct SuggestionsView: View {
    @Binding var showingSuggestions: Bool
    @Binding var showingCommands: Bool
    @Binding var messageText: String
    @EnvironmentObject var chatService: ChatService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if showingSuggestions {
                    SuggestionSection(
                        title: "💡 Suggested Questions",
                        items: chatService.contextPresets,
                        onSelect: { preset in
                            messageText = preset.prompt
                            showingSuggestions = false
                        }
                    )
                }
                
                if showingCommands {
                    CommandSection(
                        title: "⚡ Slash Commands",
                        commands: chatService.slashCommands,
                        onSelect: { command in
                            messageText = "/\(command.name) "
                            showingCommands = false
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let chatService = ChatService()
    chatService.contextPresets = [
        ContextPreset(prompt: "How to create a new branch?", category: "git"),
        ContextPreset(prompt: "What is a merge request?", category: "gitlab")
    ]
    chatService.slashCommands = [
        SlashCommand(name: "ask", description: "Ask a question"),
        SlashCommand(name: "explain", description: "Explain code")
    ]
    
    return SuggestionsView(
        showingSuggestions: .constant(true),
        showingCommands: .constant(false),
        messageText: .constant("")
    )
    .environmentObject(chatService)
    .frame(width: 400)
}

#Preview("With Commands") {
    let chatService = ChatService()
    chatService.contextPresets = [
        ContextPreset(prompt: "How to create a new branch?", category: "git")
    ]
    chatService.slashCommands = [
        SlashCommand(name: "ask", description: "Ask a question"),
        SlashCommand(name: "explain", description: "Explain code")
    ]
    
    return SuggestionsView(
        showingSuggestions: .constant(false),
        showingCommands: .constant(true),
        messageText: .constant("/")
    )
    .environmentObject(chatService)
    .frame(width: 400)
}