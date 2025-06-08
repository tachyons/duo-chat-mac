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

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ChatView()
                    .transition(.opacity)
            } else {
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}

#Preview {
    let authService = AuthenticationService()
    let chatService = ChatService(authService: authService)

    
    return ContentView()
        .environmentObject(authService)
        .environmentObject(chatService)
}

