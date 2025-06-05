import SwiftUI

struct DocumentRow: View {
    let document: Document
    var showPreview: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.title)
                .font(.headline)
            
            if showPreview {
                Text(document.content.prefix(100) + "...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label(document.source.sourceType, systemImage: sourceTypeIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
    
    private var sourceTypeIcon: String {
        switch document.source.sourceType {
        case "pdf":
            return "doc.fill"
        case "url":
            return "link"
        default:
            return "doc.text"
        }
    }
}

// Preview provider
struct DocumentRow_Previews: PreviewProvider {
    static var previews: some View {
        DocumentRow(document: Document(source: .text("Sample content"), title: "Sample Document"))
    }
} 