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
    @State private var selectedThreadID: String?
        
    var body: some Scene {
        WindowGroup {
            ContentView(selectedThreadID: $selectedThreadID)
                .environmentObject(authService)
                .environmentObject(chatService)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear() {
                    chatService.setAuthService(authService: authService)
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Duo Chat Help") {
                    let helpView = HelpView()
                    let hostingController = NSHostingController(rootView: helpView)
                    let window = NSWindow(contentViewController: hostingController)
                    window.title = "Duo Chat Help"
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        
        MenuBarExtra("Duo Chat", systemImage: "message.fill") {
            MenubarChatView()
                .environmentObject(chatService)
        }
        .menuBarExtraStyle(.window)

    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "duo-chat", let host = url.host else { return }
        
        if host == "thread" {
            // Get everything after "duo-chat://thread/"
            let threadID = url.absoluteString
                .replacingOccurrences(of: "duo-chat://thread/", with: "")
            selectedThreadID = threadID
        }
    }
}
