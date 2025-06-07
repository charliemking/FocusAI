//
//  ChatState.swift
//  LLMChat
//

import Foundation
import MLCSwift
import MLCChat
import SwiftUI

public enum MessageRole: String {
    case system
    case user
    case assistant
}

public struct MessageData: Identifiable, Hashable {
    public let id = UUID()
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    
    public init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

final class ChatState: ObservableObject {
    @Published private(set) var modelChatState: ModelChatState = .ready {
        didSet {
            objectWillChange.send()
        }
    }
    
    @Published private(set) var messages: [MessageData] = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var displayName = ""
    @Published var infoText = ""
    @Published var legacyUseImage = false
    
    private let modelChatStateLock = NSLock()
    var modelID: String?
    var modelLib: String?
    var modelPath: String?
    var estimatedVRAMReq: Double?
    
    var displayMessages: [MessageData] { messages }
    
    // the new mlc engine
    private let engine = MLCEngine()
    // history messages
    private var historyMessages = [ChatCompletionMessage]()

    // streaming text that get updated
    private var streamingText = ""

    var isGenerating: Bool {
        return modelChatState == .generating
    }
    
    var isReloading: Bool {
        return modelChatState == .reloading
    }
    
    var isError: Bool {
        if case .error = modelChatState {
            return true
        }
        return false
    }
    
    var canSendMessage: Bool {
        return modelChatState == .ready
    }
    
    init() {
    }

    var isInterruptible: Bool {
        return modelChatState == .ready
            || modelChatState == .generating
            || modelChatState == .failed
            || modelChatState == .pendingImageUpload
    }

    var isChattable: Bool {
        return modelChatState == .ready
    }

    var isUploadable: Bool {
        return modelChatState == .pendingImageUpload
    }

    var isResettable: Bool {
        return modelChatState == .ready
            || modelChatState == .generating
    }

    func requestResetChat() {
        assert(isResettable)
        interruptChat(prologue: {
            switchToResetting()
        }, epilogue: { [weak self] in
            self?.mainResetChat()
        })
    }

    // reset the chat if we switch to background
    // during generation to avoid permission issue
    func requestSwitchToBackground() {
        if (modelChatState == .generating) {
            self.requestResetChat()
        }
    }


    func requestTerminateChat(callback: @escaping () -> Void) {
        assert(isInterruptible)
        interruptChat(prologue: {
            switchToTerminating()
        }, epilogue: { [weak self] in
            self?.mainTerminateChat(callback: callback)
        })
    }

    func requestReloadChat(
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

    func requestGenerate(prompt: String) {
        assert(isChattable)
        switchToGenerating()
        appendMessage(role: .user, message: prompt)
        appendMessage(role: .assistant, message: "")

        Task {
            self.historyMessages.append(
                ChatCompletionMessage(role: .user, content: prompt)
            )
            var finishReasonLength = false
            var finalUsageTextLabel = ""

            for await res in await engine.chat.completions.create(
                messages: self.historyMessages,
                stream_options: StreamOptions(include_usage: true)
            ) {
                for choice in res.choices {
                    if let content = choice.delta.content {
                        self.streamingText += content.asText()
                    }
                    if let finish_reason = choice.finish_reason {
                        if finish_reason == "length" {
                            finishReasonLength = true
                        }
                    }
                }
                if let finalUsage = res.usage {
                    finalUsageTextLabel = finalUsage.extra?.asTextLabel() ?? ""
                }
                if modelChatState != .generating {
                    break
                }

                var updateText = self.streamingText
                if finishReasonLength {
                    updateText += " [output truncated due to context length limit...]"
                }

                let newText = updateText
                DispatchQueue.main.async {
                    self.updateMessage(role: .assistant, content: newText)
                }
            }

            // record history messages
            if !self.streamingText.isEmpty {
                self.historyMessages.append(
                    ChatCompletionMessage(role: .assistant, content: self.streamingText)
                )
                // stream text can be cleared
                self.streamingText = ""
            } else {
                self.historyMessages.removeLast()
            }

            // if we exceed history
            // we can try to reduce the history and see if it can fit
            if (finishReasonLength) {
                let windowSize = self.historyMessages.count
                assert(windowSize % 2 == 0)
                let removeEnd = ((windowSize + 3) / 4) * 2
                self.historyMessages.removeSubrange(0..<removeEnd)
            }

            if modelChatState == .generating {
                let runtimStats = finalUsageTextLabel

                DispatchQueue.main.async {
                    self.infoText = runtimStats
                    self.switchToReady()

                }
            }
        }
    }

    func isCurrentModel(modelID: String) -> Bool {
        return self.modelID == modelID
    }

    func addMessage(role: MessageRole, content: String) {
        messages.append(MessageData(role: role, content: content, timestamp: Date()))
    }

    func updateMessage(role: MessageRole, content: String) {
        messages.append(MessageData(role: role, content: content))
    }

    func clearMessages() {
        messages.removeAll()
        infoText = ""
        historyMessages.removeAll()
        streamingText = ""
    }

    func sendMessage(_ content: String) {
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
    
    private func reloadChat() async throws {
        messages.removeAll()
        historyMessages.removeAll()
        streamingText = ""
        // Add initialization code here
    }
}

private extension ChatState {
    func getModelChatState() -> ModelChatState {
        modelChatStateLock.lock()
        defer { modelChatStateLock.unlock() }
        return modelChatState
    }

    func setModelChatState(_ newState: ModelChatState) {
        modelChatStateLock.lock()
        defer { modelChatStateLock.unlock() }
        modelChatState = newState
    }

    func appendMessage(role: MessageRole, message: String) {
        messages.append(MessageData(role: role, content: message, timestamp: Date()))
    }

    func interruptChat(prologue: () -> Void, epilogue: @escaping () -> Void) {
        assert(isInterruptible)
        if modelChatState == .ready
            || modelChatState == .failed
            || modelChatState == .pendingImageUpload {
            prologue()
            epilogue()
        } else if modelChatState == .generating {
            prologue()
            DispatchQueue.main.async {
                epilogue()
            }
        } else {
            assert(false)
        }
    }

    func mainResetChat() {
        Task {
            await engine.reset()
            self.historyMessages = []
            self.streamingText = ""

            DispatchQueue.main.async {
                self.clearMessages()
                self.switchToReady()
            }
        }
    }

    func mainTerminateChat(callback: @escaping () -> Void) {
        Task {
            await engine.unload()
            DispatchQueue.main.async {
                self.clearMessages()
                self.modelID = nil
                self.modelLib = nil
                self.modelPath = nil
                self.displayName = ""
                self.legacyUseImage = false
                self.switchToReady()
                callback()
            }
        }
    }

    func mainReloadChat(modelID: String, modelLib: String, modelPath: String, estimatedVRAMReq: Int, displayName: String) {
        clearMessages()
        self.modelID = modelID
        self.modelLib = modelLib
        self.modelPath = modelPath
        self.displayName = displayName

        Task {
            DispatchQueue.main.async {
                self.appendMessage(role: .assistant, message: "[System] Initalize...")
            }

            await engine.unload()
            let vRAM = os_proc_available_memory()
            if (vRAM < estimatedVRAMReq) {
                let requiredMemory = String (
                    format: "%.1fMB", Double(estimatedVRAMReq) / Double(1 << 20)
                )
                let errorMessage = (
                    "Sorry, the system cannot provide \(requiredMemory) VRAM as requested to the app, " +
                    "so we cannot initialize this model on this device."
                )
                DispatchQueue.main.sync {
                    self.displayMessages.append(MessageData(role: MessageRole.assistant, content: errorMessage, timestamp: Date()))
                    self.switchToFailed()
                }
                return
            }
            await engine.reload(
                modelPath: modelPath, modelLib: modelLib
            )

            // run a simple prompt with empty content to warm up system prompt
            // helps to start things before user start typing
            for await _ in await engine.chat.completions.create(
                messages: [ChatCompletionMessage(role: .user, content: "")],
                max_tokens: 1
            ) {}

            // TODO(mlc-team) run a system message prefill
            DispatchQueue.main.async {
                self.updateMessage(role: .assistant, content: "[System] Ready to chat")
                self.switchToReady()
            }

        }
    }

    func switchToResetting() {
        setModelChatState(.resetting)
    }

    func switchToGenerating() {
        setModelChatState(.generating)
    }

    func switchToReloading() {
        setModelChatState(.reloading)
    }

    func switchToReady() {
        setModelChatState(.ready)
    }

    func switchToTerminating() {
        setModelChatState(.terminating)
    }

    func switchToFailed() {
        setModelChatState(.failed)
    }

    func switchToPendingImageUpload() {
        setModelChatState(.pendingImageUpload)
    }

    func switchToProcessingImage() {
        setModelChatState(.processingImage)
    }
}
