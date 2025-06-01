//
//  ThreadRowView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct ThreadRowView: View {
    let thread: ChatThread
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title)
                .font(.headline)
                .lineLimit(1)
            
//            Text(thread.createdAt, style: .relative)
//                .font(.caption)
//                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
