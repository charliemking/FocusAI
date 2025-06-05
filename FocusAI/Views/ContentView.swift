import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedDocument: Document?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PDFInputView()
                .tabItem {
                    Label("PDF", systemImage: "doc.fill")
                }
                .tag(0)
            
            TextInputView()
                .tabItem {
                    Label("Text", systemImage: "text.justify")
                }
                .tag(1)
            
            URLInputView()
                .tabItem {
                    Label("URL", systemImage: "link")
                }
                .tag(2)
            
            if let document = selectedDocument {
                StudyView(document: document)
                    .tabItem {
                        Label("Study", systemImage: "brain.head.profile")
                    }
                    .tag(3)
            } else {
                Text("Select a document to study")
                    .tabItem {
                        Label("Study", systemImage: "brain.head.profile")
                    }
                    .tag(3)
            }
        }
        .onAppear {
            // Create a sample document for testing
            selectedDocument = Document(
                source: .text("Sample content for testing"),
                title: "Sample Document"
            )
        }
    }
}

#Preview {
    ContentView()
} 