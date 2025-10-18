//
//  AuthenticationView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI


struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var gitlabURL = "https://gitlab.com"
    @State private var clientID = "a4eb2f3c8301ad0d4c45fb5a435a95df7cd332665f4666aec26bc4d5614daf1e"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                
                VStack(spacing: 8) {
                    Text("GitLab Duo Chat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-powered development assistant")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Form
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitLab Instance URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("https://gitlab.com", text: $gitlabURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("OAuth Client ID")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Your OAuth application client ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                
                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "globe")
                        }
                        Text("Sign in with GitLab")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(gitlabURL.isEmpty || clientID.isEmpty || isLoading)
            }
            .frame(maxWidth: 400)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func signIn() {
        isLoading = true
        Task {
              try  await authService.signIn(gitlabURL: gitlabURL, clientID: clientID)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
}