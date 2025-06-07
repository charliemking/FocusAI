import SwiftUI
import MarkdownUI

public struct MessageView: View {
    let message: MessageData
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Markdown(message.content)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color(.systemGray6)
        case .assistant:
            return Color(.systemBackground)
        case .system:
            return Color(.systemGray5)
        }
    }
    
    public init(message: MessageData) {
        self.message = message
    }
} 