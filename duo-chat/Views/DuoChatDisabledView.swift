//
//  DuoChatDisabledView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 29/06/25.
//


import SwiftUI

struct DuoChatDisabledView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var chatService: ChatService
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            // Title and Description
            VStack(spacing: 12) {
                Text("Duo Chat Not Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("Duo Chat is not enabled for your GitLab account.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("This feature may require a specific subscription plan or administrator approval.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                // Refresh button
                Button(action: {
                    Task {
                        await chatService.loadInitialData()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Again")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Help/Info buttons
                HStack(spacing: 16) {
                    if let gitlabURL = authService.currentGitLabURL {
                        Button(action: {
                            openGitLabDocs(gitlabURL: gitlabURL)
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Learn More")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    
                    Button(action: {
                        openGitLabSettings()
                    }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
            
            // Additional Info
            VStack(spacing: 8) {
                Divider()
                    .frame(maxWidth: 200)
                
                VStack(spacing: 4) {
                    Text("Duo Chat Features:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        FeatureItem(text: "AI-powered code assistance")
                        FeatureItem(text: "Context-aware suggestions")
                        FeatureItem(text: "GitLab integration")
                        FeatureItem(text: "Project-specific help")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func openGitLabDocs(gitlabURL: String) {
        // Try to open GitLab Duo documentation
        let docsURL = "\(gitlabURL)/-/duo_chat/docs"
        if let url = URL(string: docsURL) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to general GitLab docs
            if let fallbackURL = URL(string: "https://docs.gitlab.com/ee/user/gitlab_duo_chat/") {
                NSWorkspace.shared.open(fallbackURL)
            }
        }
    }
    
    private func openGitLabSettings() {
        guard let gitlabURL = authService.currentGitLabURL else { return }
        
        // Try to open user preferences
        let settingsURL = "\(gitlabURL)/-/profile/preferences"
        if let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Feature Item

struct FeatureItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 10))
            
            Text(text)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Alternative Compact Version

struct CompactDuoChatDisabledView: View {
    @EnvironmentObject var chatService: ChatService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Duo Chat Unavailable")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("This feature requires Duo Chat to be enabled for your account.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Refresh") {
                Task {
                    await chatService.loadInitialData()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Loading State for Duo Chat Check

struct DuoChatLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Checking Duo Chat Availability")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Verifying your account permissions...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Disabled View") {
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)
    chatService.duoChatEnabled = false
    
    return DuoChatDisabledView()
        .environmentObject(authService)
        .environmentObject(chatService)
        .frame(width: 500, height: 400)
}

#Preview("Compact Disabled") {
    let chatService = ChatService()
    chatService.duoChatEnabled = false
    
    return CompactDuoChatDisabledView()
        .environmentObject(chatService)
        .frame(width: 500, height: 100)
}

#Preview("Loading") {
    DuoChatLoadingView()
        .frame(width: 400, height: 200)
}
