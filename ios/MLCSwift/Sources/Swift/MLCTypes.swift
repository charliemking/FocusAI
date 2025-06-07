import Foundation

public enum ModelLoadingState: Equatable {
    case notLoaded
    case loading
    case loaded
    case error(Error)
    
    public static func == (lhs: ModelLoadingState, rhs: ModelLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded),
             (.loading, .loading),
             (.loaded, .loaded):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

public enum ModelChatState: Equatable {
    case ready
    case reloading
    case generating
    case error(Error)
    
    public static func == (lhs: ModelChatState, rhs: ModelChatState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready),
             (.reloading, .reloading),
             (.generating, .generating):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MessageData, rhs: MessageData) -> Bool {
        return lhs.id == rhs.id
    }
}

public struct ModelConfig {
    public let modelID: String?
    public let modelLib: String?
    public let estimatedVRAMReq: Int?
    
    public init(modelID: String?, modelLib: String?, estimatedVRAMReq: Int?) {
        self.modelID = modelID
        self.modelLib = modelLib
        self.estimatedVRAMReq = estimatedVRAMReq
    }
} 