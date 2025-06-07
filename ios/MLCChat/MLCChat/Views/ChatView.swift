//
//  ChatView.swift
//  MLCChat
//

import SwiftUI
import MLCSwift
import MarkdownUI

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading model...")
            .progressViewStyle(.circular)
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Text("Error: \(error.localizedDescription)")
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct MemoryUsageView: View {
    var body: some View {
        Text("Memory usage information will be displayed here")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct ChatView: View {
    @StateObject var chatState = ChatState()
    @State private var inputText = ""
    @State private var isInputEnabled = true
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chatState.messages) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!isInputEnabled)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(inputText.isEmpty || !isInputEnabled)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .alert("Error", isPresented: $chatState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatState.errorMessage)
        }
        .onAppear {
            let config = ModelConfig(
                tokenizerFiles: ["tokenizer.json"],
                modelLib: "mlc-chat-Mistral-7B-v0.1-q4f16_1",
                modelID: "mistral-7b-v0.1",
                estimatedVRAMReq: 8000
            )
            chatState.requestReloadChat(
                modelID: config.modelID ?? "",
                modelLib: config.modelLib ?? "",
                modelPath: "/path/to/model",
                estimatedVRAMReq: Double(config.estimatedVRAMReq ?? 8000),
                displayName: "Mistral 7B"
            )
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let message = inputText
        inputText = ""
        isInputEnabled = false
        
        chatState.sendMessage(message)
        isInputEnabled = true
    }
}

struct MessageView: View {
    let message: MessageData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Markdown(message.content)
                .markdownTheme(.gitHub)
        }
        .padding()
        .background(message.role == .assistant ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        ChatView()
    }
}
