
import SwiftUI

struct MenubarChatView: View {
    @EnvironmentObject var chatService: ChatService
    @State private var query: String = ""
    @State private var isLoading: Bool = false
    @State private var activeThreadID: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Text("Duo Chat")
                .font(.headline)
            
            ScrollView {
                if let threadID = activeThreadID, let messages = chatService.messages[threadID] {
                    ForEach(messages) {
                        MessageView(message: $0)
                    }
                } else {
                    Text("Ask me anything!")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .frame(height: 150)

            Spacer()
            
            HStack {
                Button(action: openFullApp) {
                    Text("Open in App")
                }
                Button(action: resetConversation) {
                    Text("Reset")
                }
            }

            HStack {
                TextField("Ask a question...", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit(performQuery)
  

                if isLoading {
                    ProgressView()
                } else {
                    Button(action: performQuery) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(query.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear(perform: setupNewThreadCallback)
    }

    private func setupNewThreadCallback() {
        chatService.onNewThreadCreated = { threadID in
            self.activeThreadID = threadID
        }
    }
    
    private func openFullApp() {
        var urlString = "duo-chat://"
        if let threadID = activeThreadID {
            urlString += "thread/\(threadID)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func resetConversation() {
        query = ""
        isLoading = false
        activeThreadID = nil
    }

    private func performQuery() {
        guard !query.isEmpty else { return }
        isLoading = true
        let currentQuery = query
        query = "" // Clear input field immediately

        Task {
            await chatService.sendMessage(content: currentQuery, threadID: activeThreadID)
            isLoading = false
        }
    }
}

#Preview {
    MenubarChatView()
        .environmentObject(ChatService()) // Provide a mock ChatService for preview
}
