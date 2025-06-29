// MARK: - WebSocket Manager
import SwiftUI

@MainActor
class WebSocketManager: NSObject, ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var isConnected = false
    private var isWelcomeReceived = false
    private var reconnectTimer: Timer?
    private var subscriptions: [String: SubscriptionHandler] = [:]
    private var pendingSubscriptions: [(query: String, variables: [String: Any], operationName: String, handler: (Data) -> Void)] = []
    
    struct SubscriptionHandler {
        let identifier: String
        let nonce: String
        let operationName: String
        let handler: (Data) -> Void
    }
    
    weak var authService: AuthenticationService?
    var onConnectionReady: (() -> Void)?
    
    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        super.init()
    }
    
    func connect() async {
        guard let authService = authService,
              let gitlabURL = authService.currentGitLabURL,
              let accessToken = authService.currentAccessToken else {
            print("❌ Cannot connect WebSocket: Missing auth info")
            return
        }
        
        isConnected = false
        isWelcomeReceived = false
        
        let wsURL = gitlabURL.replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsURL)/-/cable") else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("actioncable-v1-json, actioncable-unsupported", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.setValue("permessage-deflate", forHTTPHeaderField: "Sec-WebSocket-Extensions")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("websocket", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("websocket", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue(gitlabURL, forHTTPHeaderField: "Origin")
        request.setValue("GitLabDuoChatMac/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔌 WebSocket connecting to \(url)")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        
        await startListening()
    }
    
    func disconnect() {
        print("🔌 Disconnecting WebSocket...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isWelcomeReceived = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        subscriptions.removeAll()
        pendingSubscriptions.removeAll()
        print("🔌 WebSocket disconnected")
    }
    
    func subscribeToGraphQL(query: String, variables: [String: Any], operationName: String, onMessage: @escaping (Data) -> Void) async -> String {
        if !isWelcomeReceived {
            print("⏳ Queueing subscription until WebSocket is ready: \(operationName)")
            pendingSubscriptions.append((query: query, variables: variables, operationName: operationName, handler: onMessage))
            return "\(operationName)_pending"
        }
        
        let nonce = UUID().uuidString
        
        print("📡 Creating GraphQL subscription:")
        print("   Operation: \(operationName)")
        print("   Nonce: \(nonce)")
        print("   Variables: \(variables)")
        
        let identifier: [String: Any] = [
            "channel": "GraphqlChannel",
            "query": query,
            "variables": variables,
            "operationName": operationName,
            "nonce": nonce
        ]
        
        guard let identifierData = try? JSONSerialization.data(withJSONObject: identifier),
              let identifierString = String(data: identifierData, encoding: .utf8) else {
            print("❌ Failed to serialize subscription identifier")
            return ""
        }
        
        print("📋 Subscription identifier: \(identifierString)")
        
        let subscribeMessage: [String: Any] = [
            "command": "subscribe",
            "identifier": identifierString
        ]
        
        let subscriptionId = "\(operationName)_\(nonce)"
        
        subscriptions[subscriptionId] = SubscriptionHandler(
            identifier: identifierString,
            nonce: nonce,
            operationName: operationName,
            handler: onMessage
        )
        
        await sendMessage(subscribeMessage)
        print("📡 Subscribed to GraphQL: \(operationName) with ID: \(subscriptionId)")
        print("📊 Total active subscriptions: \(subscriptions.count)")
        
        return subscriptionId
    }
    
    func unsubscribeFromGraphQL(subscriptionId: String) async {
        guard let subscription = subscriptions[subscriptionId] else {
            print("⚠️ Subscription not found: \(subscriptionId)")
            return
        }
        
        let unsubscribeMessage: [String: Any] = [
            "command": "unsubscribe",
            "identifier": subscription.identifier
        ]
        
        await sendMessage(unsubscribeMessage)
        subscriptions.removeValue(forKey: subscriptionId)
        
        print("📡 Unsubscribed from GraphQL: \(subscriptionId)")
    }
    
    private func processPendingSubscriptions() async {
        print("🔄 Processing \(pendingSubscriptions.count) pending subscriptions...")
        
        for pending in pendingSubscriptions {
            let _ = await subscribeToGraphQL(
                query: pending.query,
                variables: pending.variables,
                operationName: pending.operationName,
                onMessage: pending.handler
            )
        }
        
        pendingSubscriptions.removeAll()
    }
    
    private func startListening() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            while isConnected {
                let message = try await webSocketTask.receive()
                await handleMessage(message)
            }
        } catch {
            print("❌ WebSocket listening error: \(error)")
            if isConnected {
                await scheduleReconnect()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            await processMessage(data)
            
        case .data(let data):
            await processMessage(data)
            
        @unknown default:
            print("⚠️ Unknown WebSocket message type")
        }
    }
    
    private func processMessage(_ data: Data) async {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📨 Received WebSocket message: \(json)")
                
                if let type = json["type"] as? String {
                    switch type {
                    case "welcome":
                        print("✅ WebSocket connection established")
                        isWelcomeReceived = true
                        await processPendingSubscriptions()
                        onConnectionReady?()
                        
                    case "ping":
                        let pongResponse = ["type": "pong"]
                        if let pongData = try? JSONSerialization.data(withJSONObject: pongResponse),
                           let pongString = String(data: pongData, encoding: .utf8) {
                            try? await webSocketTask?.send(.string(pongString))
                        }
                        
                    case "confirm_subscription":
                        print("✅ Subscription confirmed")
                        
                    case "reject_subscription":
                        print("❌ Subscription rejected")
                        
                    default:
                        print("⚠️ Unknown message type: \(type)")
                    }
                }
                
                if let identifier = json["identifier"] as? String,
                   let message = json["message"] as? [String: Any] {
                    
                    print("📬 Received subscription message:")
                    print("   Identifier: \(identifier)")
                    print("   Message: \(message)")
                    
                    for (subscriptionId, handler) in subscriptions {
                        if identifier == handler.identifier {
                            print("✅ Found matching subscription: \(subscriptionId)")
                            if let messageData = try? JSONSerialization.data(withJSONObject: json) {
                                handler.handler(messageData)
                            }
                            break
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to decode WebSocket message: \(error)")
            if let rawString = String(data: data, encoding: .utf8) {
                print("Raw message: \(rawString)")
            }
        }
    }
    
    private func sendMessage(_ message: [String: Any]) async {
        guard let webSocketTask = webSocketTask else {
            print("❌ WebSocket task not available")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ Failed to convert message to string")
                return
            }
            
            print("📤 Sending WebSocket message: \(jsonString)")
            try await webSocketTask.send(.string(jsonString))
            
        } catch {
            print("❌ Failed to send WebSocket message: \(error)")
        }
    }
    
    private func scheduleReconnect() async {
        guard isConnected else { return }
        
        print("🔄 Scheduling WebSocket reconnect in 5 seconds...")
        
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        if isConnected {
            await connect()
        }
    }
}
