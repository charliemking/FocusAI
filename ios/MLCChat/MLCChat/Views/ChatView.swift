//
//  ChatView.swift
//  MLCChat
//

import SwiftUI
import GameController
import MLCSwift

struct ChatView: View {
    @StateObject private var chatState = ChatState()
    @ObservedObject var modelState: ModelState
    @Environment(\.scenePhase) var scenePhase
    @State private var inputText = ""
    @State private var isGenerating = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Namespace private var messagesBottomID

    // vision-related properties
    @State private var showActionSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var imageConfirmed: Bool = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var image: UIImage?

    var body: some View {
        Group {
            switch modelState.loadingState {
            case .notLoaded, .loading:
                LoadingView(message: "Loading AI Model...")
            case .loaded:
                mainChatView
            case .error(let error):
                ErrorView(error: error) {
                    modelState.loadModel()
                }
            }
        }
        .onAppear {
            if case .notLoaded = modelState.loadingState {
                modelState.loadModel()
            }
        }
        .navigationBarTitle("MLC Chat: \(chatState.displayName)", displayMode: .inline)
        .navigationBarBackButtonHidden()
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                modelState.handleBackground()
            case .active:
                modelState.handleForeground()
            default:
                break
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .buttonStyle(.borderless)
                .disabled(!chatState.isInterruptible)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    MemoryUsageView()
                    
                    Button("Reset") {
                        image = nil
                        imageConfirmed = false
                        chatState.requestResetChat()
                    }
                    .padding()
                    .disabled(!chatState.isResettable)
                }
            }
        }
    }
    
    private var mainChatView: some View {
        VStack {
            modelInfoView
            messagesView
            uploadImageView
            messageInputView
        }
        .alert("Error", isPresented: $chatState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatState.errorMessage ?? "An unknown error occurred")
        }
    }

    private var modelInfoView: some View {
        Text(chatState.infoText)
            .multilineTextAlignment(.center)
            .opacity(0.5)
            .listRowSeparator(.hidden)
    }

    private var messagesView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack {
                    let messageCount = chatState.displayMessages.count
                    let hasSystemMessage = messageCount > 0 && chatState.displayMessages[0].role == MessageRole.assistant
                    let startIndex = hasSystemMessage ? 1 : 0

                    // display the system message
                    if hasSystemMessage {
                        MessageView(role: chatState.displayMessages[0].role, message: chatState.displayMessages[0].message, isMarkdownSupported: false)
                    }

                    // display image
                    if let image, imageConfirmed {
                        ImageView(image: image)
                    }

                    // display conversations
                    ForEach(chatState.displayMessages[startIndex...], id: \.id) { message in
                        MessageView(role: message.role, message: message.message)
                    }
                    HStack { EmptyView() }
                        .id(messagesBottomID)
                }
            }
            .onChange(of: chatState.displayMessages) { _ in
                withAnimation {
                    scrollViewProxy.scrollTo(messagesBottomID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var uploadImageView: some View {
        if chatState.legacyUseImage && !imageConfirmed {
            if image == nil {
                Button("Upload picture to chat") {
                    showActionSheet = true
                }
                .actionSheet(isPresented: $showActionSheet) {
                    ActionSheet(title: Text("Choose from"), buttons: [
                        .default(Text("Photo Library")) {
                            showImagePicker = true
                            imageSourceType = .photoLibrary
                        },
                        .default(Text("Camera")) {
                            showImagePicker = true
                            imageSourceType = .camera
                        },
                        .cancel()
                    ])
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $image,
                                showImagePicker: $showImagePicker,
                                imageSourceType: imageSourceType)
                }
                .disabled(!chatState.isUploadable)
            } else {
                VStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 300, height: 300)

                        HStack {
                            Button("Undo") {
                                self.image = nil
                            }
                            .padding()

                            Button("Submit") {
                                imageConfirmed = true
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }

    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom) {
                TextField("Type a message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .disabled(isGenerating)
                
                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty && !isGenerating)
            }
            .padding()
        }
        .background(.thinMaterial)
    }
    
    private func sendMessage() {
        if isGenerating {
            // TODO: Implement stop generation
            return
        }
        
        guard !inputText.isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        
        Task {
            isGenerating = true
            defer { isGenerating = false }
            
            do {
                let response = try await modelState.generate(prompt: userMessage)
                await chatState.addMessage(role: .user, content: userMessage)
                await chatState.addMessage(role: .assistant, content: response)
            } catch {
                await chatState.showError(message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    ChatView(modelState: ModelState())
}
