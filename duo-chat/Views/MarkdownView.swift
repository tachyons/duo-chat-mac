//
//  MarkdownView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let content: String
    
    var body: some View {
        Markdown(content)
            .textSelection(.enabled)
    }
}

#Preview {
    MarkdownView(content: "#Hello, World!")
}
