//
//  duo_chatApp.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//


import SwiftUI
import Combine
import Foundation
import AuthenticationServices
import WebKit

@main
struct duo_chatApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var chatService = ChatService()
        
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(chatService)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear() {
                    chatService.setAuthService(authService: authService)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        MenuBarExtra("Duo Chat", systemImage: "message.fill") {
            MenubarChatView()
                .environmentObject(chatService)
        }
    }
}
