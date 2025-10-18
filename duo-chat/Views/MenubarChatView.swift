
import SwiftUI

struct MenubarChatView: View {
    @EnvironmentObject var chatService: ChatService
    @State private var query: String = ""
    @State private var response: String = "Ask me anything!"
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Duo Chat")
                .font(.headline)
            
            ScrollView {
                Text(response)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 150)

            Spacer() // Pushes the input field to the bottom

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
    }

    private func performQuery() {
        guard !query.isEmpty else { return }
        isLoading = true
        let currentQuery = query
        query = "" // Clear input field immediately

        Task {
            do {
                // Call the correct method to send the message
                await chatService.sendMessage(content: currentQuery, threadID: nil)
                
                // Observe the chatService.messages for the response
                // For simplicity, we'll just take the latest assistant message
                // in the first thread (or a new thread if created).
                // A more robust solution would involve tracking the specific request.
                if let latestThread = chatService.threads.first, let messages = chatService.messages[latestThread.id] {
                    if let lastAssistantMessage = messages.last(where: { $0.role == .assistant }) {
                        response = lastAssistantMessage.content
                    } else {
                        response = "No assistant response yet."
                    }
                } else {
                    response = "No active chat thread or messages."
                }
            } catch {
                response = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    MenubarChatView()
        .environmentObject(ChatService()) // Provide a mock ChatService for preview
}
