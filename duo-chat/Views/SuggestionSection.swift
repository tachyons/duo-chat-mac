//
//  SuggestionSection.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//
import SwiftUI

struct SuggestionSection: View {
    let title: String
    let items: [ContextPreset]
    let onSelect: (ContextPreset) -> Void
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                
                LazyVStack(spacing: 4) {
                    ForEach(items, id: \.prompt) { preset in
                        Button(action: { onSelect(preset) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                
                                
                                Text(preset.prompt)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

#Preview {
    let mockPresets = [
        ContextPreset(prompt: "How to use Git?", category: "git"),
        ContextPreset(prompt: "What is a merge request?", category: "gitlab"),
        ContextPreset(prompt: "Explain CI/CD pipelines", category: "devops")
    ]
    
    return SuggestionSection(
        title: "Popular Questions",
        items: mockPresets,
        onSelect: { preset in
            print("Selected preset: \(preset.prompt)")
        }
    )
    .padding()
    .frame(width: 300)
}