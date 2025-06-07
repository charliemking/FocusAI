import Foundation

public enum ModelLoadingState {
    case notLoaded
    case loading
    case loaded
    case error(Error)
}

public enum ModelChatState {
    case generating
    case resetting
    case reloading
    case terminating
    case ready
    case failed
    case pendingImageUpload
    case processingImage
    case error(Error)
}

public enum MessageRole: String {
    case user
    case assistant
    case system
}

extension MessageRole {
    public var isUser: Bool { self == .user }
}

public struct MessageData: Identifiable, Hashable {
    public let id = UUID()
    public var role: MessageRole
    public var content: String
    public let timestamp: Date
    
    public init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MessageData, rhs: MessageData) -> Bool {
        lhs.id == rhs.id
    }
} 