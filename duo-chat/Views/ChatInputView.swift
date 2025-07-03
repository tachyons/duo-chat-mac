//
//  ChatInputView.swift
//  duo-chat
//
//  Created by Aboobacker MK on 01/06/25.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var showingSuggestions: Bool
    @Binding var showingCommands: Bool
    let threadID: String?
    @EnvironmentObject var chatService: ChatService
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingContextPresets = false
    @State private var showingURLInput = false
    @State private var urlInput: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // URL Context Display and Input
            URLContextSection()

            // Context Presets (for new conversations)
            if threadID == nil && !chatService.contextPresets.isEmpty && showingContextPresets {
                ContextPresetsView(messageText: $messageText)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Suggestions and Commands
            if showingSuggestions || showingCommands {
                SuggestionsView(
                    showingSuggestions: $showingSuggestions,
                    showingCommands: $showingCommands,
                    messageText: $messageText
                )
            }

            // Helper Buttons
            HStack(spacing: 8) {
                Button(action: { showingSuggestions.toggle() }) {
                    Label("Suggestions", systemImage: "lightbulb")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { showingCommands.toggle() }) {
                    Label("Commands", systemImage: "terminal")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Context Presets button (only for new conversations)
                if threadID == nil && !chatService.contextPresets.isEmpty {
                    Button(action: { showingContextPresets.toggle() }) {
                        Label("Context", systemImage: "doc.text")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(showingContextPresets ? .blue : .primary)
                }

                Spacer()

                // Helper text
                Text("⌘⏎ Send • ⇧⏎ New line")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Message Input
            HStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if messageText.isEmpty {
                        Text(
                            chatService.duoChatEnabled
                                ? "Ask Duo Chat anything..."
                                : "Duo Chat is not available for your account"
                        )
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    TextEditor(text: $messageText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 30, maxHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .focused($isTextFieldFocused)
                        .disabled(!chatService.duoChatEnabled)
                        .onChange(of: messageText) { _, newValue in
                            updateSuggestions(for: newValue)
                        }
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: NSNotification.Name("NSControlTextDidEndEditingNotification"))
                        ) { notification in
                            // Handle text editing notifications if needed
                        }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(
                        systemName: chatService.isLoading ? "stop.circle" : "arrow.up.circle.fill"
                    )
                    .font(.title2)
                    .foregroundColor(canSendMessage ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingContextPresets)
        .onAppear {
            isTextFieldFocused = true
            urlInput = chatService.customContextURL

            // Auto-show context presets for new conversations if available
            if threadID == nil && !chatService.contextPresets.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingContextPresets = true
                }
            }
        }
    }

    // MARK: - URL Context Section
    @ViewBuilder
    private func URLContextSection() -> some View {
        VStack(spacing: 8) {
            // Current context display
            HStack(spacing: 8) {
                Image(systemName: chatService.urlContextType.icon)
                    .foregroundColor(.blue)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Context:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(chatService.urlContextType.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    if let projectID = chatService.detectedProjectID {
                        HStack {
                            Text("Project:")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(projectID)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.1), in: Capsule())
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    showingURLInput.toggle()
                    if showingURLInput {
                        urlInput = chatService.customContextURL
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isURLFieldFocused = true
                        }
                    }
                }) {
                    Image(systemName: showingURLInput ? "xmark.circle.fill" : "link.circle")
                        .font(.caption)
                        .foregroundColor(showingURLInput ? .red : .blue)
                }
                .buttonStyle(.plain)
                .help(showingURLInput ? "Cancel" : "Set Custom Context URL")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            // URL input field (when expanded)
            if showingURLInput {
                HStack(spacing: 8) {
                    TextField("Enter GitLab URL (project, issue, MR, etc.)", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .focused($isURLFieldFocused)
                        .onSubmit {
                            applyURLContext()
                        }

                    Button("Apply") {
                        applyURLContext()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !chatService.customContextURL.isEmpty {
                        Button("Clear") {
                            clearURLContext()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .transition(.slide)
            }
        }
    }

    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatService.isLoading && chatService.duoChatEnabled
    }

    private func sendMessage() {
        guard canSendMessage else { return }

        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false
        showingContextPresets = false
        showingSuggestions = false
        showingCommands = false

        Task {
            await chatService.sendMessage(content: content, threadID: threadID)
        }
    }

    private func updateSuggestions(for text: String) {
        showingCommands = text.hasPrefix("/") && text.count > 1
        // You can add more suggestion logic here
    }

    private func applyURLContext() {
        let trimmedURL = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        chatService.setCustomContextURL(trimmedURL)
        showingURLInput = false

        // Reload context-dependent data
        Task {
            await chatService.loadContextPresets()
            await chatService.loadSlashCommands()

            // Show context presets if this is a new conversation and we have some
            await MainActor.run {
                if threadID == nil && !chatService.contextPresets.isEmpty {
                    showingContextPresets = true
                }
            }
        }
    }

    private func clearURLContext() {
        chatService.setCustomContextURL("")
        urlInput = ""
        showingURLInput = false
        showingContextPresets = false

        // Reload with default context
        Task {
            await chatService.loadContextPresets()
            await chatService.loadSlashCommands()
        }
    }
}

// MARK: - Context Presets View

struct ContextPresetsView: View {
    @Binding var messageText: String
    @EnvironmentObject var chatService: ChatService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)

                Text("Context-based suggestions")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if let projectID = chatService.detectedProjectID {
                    Text(projectID)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundColor(.blue)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 200), spacing: 8)
                ], spacing: 8
            ) {
                ForEach(Array(chatService.contextPresets.prefix(6).enumerated()), id: \.offset) {
                    index, preset in
                    Button(action: {
                        messageText = preset.prompt
                    }) {
                        HStack {
                            Text(preset.prompt)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
