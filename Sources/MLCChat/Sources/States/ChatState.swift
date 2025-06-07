import Foundation
import MLCSwift
import SwiftUI

public final class ChatState: ObservableObject {
    @Published public private(set) var modelChatState: ModelChatState = .ready {
        didSet {
            objectWillChange.send()
        }
    }
    
    @Published public private(set) var messages: [MessageData] = []
    @Published public var showError = false
    @Published public var errorMessage = ""
    @Published public var displayName = ""
    @Published public var infoText = ""
    
    private let modelChatStateLock = NSLock()
    public var modelID: String?
    public var modelLib: String?
    public var modelPath: String?
    public var estimatedVRAMReq: Double?
    
    private let engine = MLCEngine()
    private var historyMessages = [ChatCompletionMessage]()
    private var streamingText = ""

    public var isGenerating: Bool {
        return modelChatState == .generating
    }
    
    public var isReloading: Bool {
        return modelChatState == .reloading
    }
    
    public var isError: Bool {
        if case .error = modelChatState {
            return true
        }
        return false
    }
    
    public var canSendMessage: Bool {
        return modelChatState == .ready
    }
    
    public func sendMessage(_ content: String) {
        guard canSendMessage else { return }
        
        updateMessage(role: .user, content: content)
        setModelChatState(.generating)
        
        Task {
            do {
                var response = ""
                for try await chunk in engine.chat.completions.create(messages: [.init(role: .user, content: content)]) {
                    if let delta = chunk.choices.first?.delta.content {
                        response += delta
                        updateMessage(role: .assistant, content: response)
                    }
                }
                setModelChatState(.ready)
            } catch {
                setModelChatState(.error(error))
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func updateMessage(role: MessageRole, content: String) {
        messages.append(MessageData(role: role, content: content))
    }
    
    private func setModelChatState(_ newState: ModelChatState) {
        modelChatStateLock.lock()
        defer { modelChatStateLock.unlock() }
        modelChatState = newState
    }
    
    public func requestReloadChat(
        modelID: String,
        modelLib: String,
        modelPath: String,
        estimatedVRAMReq: Double,
        displayName: String
    ) {
        self.modelID = modelID
        self.modelLib = modelLib
        self.modelPath = modelPath
        self.estimatedVRAMReq = estimatedVRAMReq
        self.displayName = displayName
        
        setModelChatState(.reloading)
        
        Task {
            do {
                try await reloadChat()
                setModelChatState(.ready)
            } catch {
                setModelChatState(.error(error))
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func reloadChat() async throws {
        messages.removeAll()
        historyMessages.removeAll()
        streamingText = ""
    }
} 