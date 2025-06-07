import Foundation

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

public enum ModelChatState {
    case generating
    case ready
    case reloading
    case error(Error)
}

public enum ModelLoadingState {
    case notLoaded
    case loading
    case loaded
    case error(Error)
} 