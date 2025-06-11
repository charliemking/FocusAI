import SwiftUI

enum Theme {
    static let primaryBlue = Color(red: 0.0, green: 0.28, blue: 0.70)
    static let lightBlue = Color(red: 0.85, green: 0.92, blue: 1.0)
    static let backgroundWhite = Color(red: 0.98, green: 0.98, blue: 0.98)
    
    static let headerStyle = Font.system(size: 24, weight: .medium, design: .rounded)
    static let subtitleStyle = Font.system(size: 14, weight: .regular, design: .rounded)
    
    static let groupBoxStyle = CustomGroupBoxStyle(backgroundColor: .white)
}

struct CustomGroupBoxStyle: ViewModifier {
    let backgroundColor: Color
    
    init(backgroundColor: Color) {
        self.backgroundColor = backgroundColor
    }
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func customGroupBox() -> some View {
        self.modifier(Theme.groupBoxStyle)
    }
} 