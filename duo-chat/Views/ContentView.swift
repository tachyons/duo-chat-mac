//
//  ContentView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var chatService: ChatService
    @Binding var selectedThreadID: String?

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ChatView(selectedThreadID: $selectedThreadID)
                    .transition(.opacity)
            } else {
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .alert("Chat Service Error", isPresented: .constant(chatService.error != nil)) {
            Button("OK") {
                chatService.error = nil
            }
        } message: {
            if let error = chatService.error {
                Text(error.localizedDescription)
            }
        }
    }
}

#Preview {
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)
    
    ContentView(selectedThreadID: .constant(nil))
        .environmentObject(authService)
        .environmentObject(chatService)
}

