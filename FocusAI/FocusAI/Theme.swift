import SwiftUI

enum Theme {
    static let primaryColor = Color(red: 0.20, green: 0.76, blue: 0.55) // Teal Green
    static let lightAccent = Color(red: 0.94, green: 0.98, blue: 0.96) // Light mint accent
    static let backgroundWhite = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let backgroundColor = Color(white: 0.95)
    
    // System fonts
    static let headerStyle = Font.system(size: 36, weight: .bold)
    static let subtitleStyle = Font.system(size: 21, weight: .bold)
    static let bodyStyle = Font.system(size: 18, weight: .regular)
    static let captionStyle = Font.system(size: 18, weight: .regular)
    static let titleStyle = Font.system(size: 30, weight: .medium)
    static let buttonStyle = Font.system(size: 24, weight: .semibold)
    
    // Processing screen fonts
    static let processingTitleStyle = Font.system(size: 27, weight: .medium)
    static let processingSubtitleStyle = Font.system(size: 19, weight: .regular)
    
    // Subtitle with title size but lighter weight
    static let titleRegularStyle = Font.system(size: 21, weight: .medium)
} 