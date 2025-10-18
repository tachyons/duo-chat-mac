//
//  CommandSection.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct CommandSection: View {
    let title: String
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void
    
    var body: some View {
        if !commands.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                
                LazyVStack(spacing: 4) {
                    ForEach(commands, id: \.name) { command in
                        Button(action: { onSelect(command) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("/\(command.name)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .monospaced()
                                
                                Text(command.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                               
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
    let mockCommands = [
        SlashCommand(name: "ask", description: "Ask a question"),
        SlashCommand(name: "explain", description: "Explain code or concept"),
        SlashCommand(name: "refactor", description: "Refactor selected code")
    ]
    
    return CommandSection(
        title: "Available Commands",
        commands: mockCommands,
        onSelect: { command in
            print("Selected command: \(command.name)")
        }
    )
    .padding()
    .frame(width: 300)
}