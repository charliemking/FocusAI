import SwiftUI

public struct ModelView: View {
    @EnvironmentObject private var modelState: ModelState
    @EnvironmentObject private var chatState: ChatState
    @Binding var isRemoving: Bool
    
    @State private var isShowingDeletionConfirmation = false
    
    public var body: some View {
        VStack(alignment: .leading) {
            if modelState.modelDownloadState == .finished {
                NavigationLink {
                    ChatView()
                        .environmentObject(chatState)
                        .onAppear {
                            modelState.startChat(chatState: chatState)
                        }
                } label: {
                    HStack {
                        Text(modelState.modelConfig.modelID ?? "Unknown Model")
                        Spacer()
                        if chatState.isCurrentModel(modelID: modelState.modelID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            } else {
                Text(modelState.modelConfig.modelID ?? "Unknown Model")
            }
            
            if modelState.modelDownloadState == .downloading {
                ProgressView(value: Double(modelState.progress), total: Double(modelState.total))
                    .progressViewStyle(.linear)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                isShowingDeletionConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Model", isPresented: $isShowingDeletionConfirmation) {
            Button("Delete", role: .destructive) {
                isRemoving = true
                modelState.deleteModel()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this model? This action cannot be undone.")
        }
    }
    
    public init(isRemoving: Binding<Bool>) {
        self._isRemoving = isRemoving
    }
} 