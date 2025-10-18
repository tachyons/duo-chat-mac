//
//  ThreadRowView.swift
//  duo-chat
//
//  Enhanced with better visual feedback for deletion
//
import SwiftUI

struct ThreadRowView: View {
    let thread: ChatThread
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    if let lastUpdatedDate = parseLastUpdatedDate() {
                        Text(lastUpdatedDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle()) // Makes entire row tappable
    }
    
    private func parseLastUpdatedDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: thread.lastUpdatedAt) {
            return date
        }
        
        // Fallback to a simpler format if the above fails
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        simpleDateFormatter.timeZone = TimeZone(abbreviation: "UTC") 
        return simpleDateFormatter.date(from: thread.lastUpdatedAt)
    }
}

#Preview {
    let sampleThread = ChatThread(
        id: "sample-id",
        title: "Sample conversation about Swift development",
        conversationType: "DUO_CHAT",
        createdAt: "2025-06-08T10:00:00Z",
        lastUpdatedAt: "2025-06-08T10:30:00Z"
    )
    
    ThreadRowView(thread: sampleThread)
        .padding()
}
