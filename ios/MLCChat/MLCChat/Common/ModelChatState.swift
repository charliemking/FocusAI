import Foundation

enum ModelChatState {
    case generating
    case resetting
    case reloading
    case terminating
    case ready
    case failed
    case pendingImageUpload
    case processingImage
} 