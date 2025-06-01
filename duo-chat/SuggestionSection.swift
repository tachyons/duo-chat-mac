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
                    ForEach(items, id: \.name) { preset in
                        Button(action: { onSelect(preset) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(preset.prompt)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
