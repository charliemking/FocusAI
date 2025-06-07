import Foundation
import TestCore

public class MLCChatTestBridge: MLCChatBridge {
    public let chatState: ChatStateProtocol
    public let mlcSwift: MLCSwiftProtocol
    
    public init(chatState: ChatStateProtocol = TestChatState(),
                mlcSwift: MLCSwiftProtocol = MockMLCSwift()) {
        self.chatState = chatState
        self.mlcSwift = mlcSwift
    }
    
    public func processUserMessage(_ content: String) async throws -> String {
        let userMessage = Message(content: content, role: .user)
        chatState.addMessage(userMessage)
        
        let response = mlcSwift.generate(prompt: content)
        let assistantMessage = Message(content: response, role: .assistant)
        chatState.addMessage(assistantMessage)
        
        return response
    }
    
    public func reset() {
        chatState.clearMessages()
        mlcSwift.reset()
    }
} 