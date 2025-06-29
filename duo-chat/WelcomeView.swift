//
//  WelcomeView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 29/06/25.
//


//
//  WelcomeView.swift
//  duo-chat
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var chatService: ChatService
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "message.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("GitLab Duo Chat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Start a conversation with your AI assistant")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Features
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "link.circle",
                    title: "Context-Aware",
                    description: "Set a GitLab URL to get relevant suggestions and project-specific help"
                )
                
                FeatureRow(
                    icon: "lightbulb.circle",
                    title: "Smart Suggestions",
                    description: "Get contextual prompts based on your current GitLab page or project"
                )
                
                FeatureRow(
                    icon: "command.circle",
                    title: "Slash Commands",
                    description: "Use / commands for quick actions and specialized tasks"
                )
            }
            .padding(.horizontal, 32)
            
            // Status indicator
            if chatService.duoChatEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Duo Chat is enabled and ready")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.green.opacity(0.1), in: Capsule())
            } else {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Duo Chat is not enabled for your account")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: Capsule())
            }
        }
        .padding(32)
        .frame(maxWidth: 500)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}



#Preview("Welcome") {
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)
    chatService.duoChatEnabled = true
    
    return WelcomeView()
        .environmentObject(chatService)
        .frame(width: 600, height: 500)
}



#Preview("Loading") {
    LoadingMessageView()
        .frame(width: 400, height: 100)
}
