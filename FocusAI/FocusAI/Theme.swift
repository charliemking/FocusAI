import SwiftUI

enum Theme {
    static let primaryColor = Color(red: 0.0, green: 0.66, blue: 0.35) // Emerald Green
    static let lightAccent = Color(red: 0.94, green: 0.98, blue: 0.96) // Light mint accent
    static let backgroundWhite = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let backgroundColor = Color(white: 0.95)
    
    // FreightText fonts (50% larger) using specific font names
    static let headerStyle = Font.custom("FreightText Pro Bold", size: 36) // Slightly bolder than titles
    static let subtitleStyle = Font.custom("FreightText Pro Bold", size: 21) // Bold for subtitle
    static let bodyStyle = Font.custom("FreightText Pro Book", size: 24)
    static let captionStyle = Font.custom("FreightText Pro Book", size: 18)
    static let titleStyle = Font.custom("FreightText Pro Medium", size: 30) // Section titles (Summary, Flashcards)
    static let buttonStyle = Font.custom("FreightText Pro Semibold", size: 24)
    
    // Processing screen fonts (33% larger than original)
    static let processingTitleStyle = Font.custom("FreightText Pro Bold", size: 27) // 20 * 1.33 ≈ 27
    static let processingSubtitleStyle = Font.custom("FreightText Pro Book", size: 19) // 14 * 1.33 ≈ 19
} 