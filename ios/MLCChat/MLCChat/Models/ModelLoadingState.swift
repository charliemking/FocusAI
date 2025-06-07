import Foundation

enum ModelLoadingState {
    case notLoaded
    case loading
    case loaded
    case error(Error)
} 