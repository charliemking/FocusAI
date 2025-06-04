import SwiftUI

struct StudyView: View {
    @State private var documents: [Document] = []
    
    var body: some View {
        NavigationView {
            List {
                if documents.isEmpty {
                    Text("No study materials yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(documents) { document in
                        DocumentRow(document: document)
                    }
                }
            }
            .navigationTitle("Study Materials")
        }
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.title)
                .font(.headline)
            
            if let summary = document.summary {
                Text("Summary available")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            if let flashcards = document.flashcards {
                Text("\(flashcards.count) flashcards")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Text(document.dateCreated, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StudyView()
} 