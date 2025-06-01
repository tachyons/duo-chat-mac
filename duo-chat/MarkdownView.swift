//
//  MarkdownView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct MarkdownView: View {
    let content: String
    
    var body: some View {
        // For now, we'll use a simple text view
        // In a real app, you'd want to integrate a markdown parsing library
        Text(content)
            .textSelection(.enabled)
    }
}
