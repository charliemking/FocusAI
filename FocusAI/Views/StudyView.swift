import SwiftUI

struct StudyView: View {
    @ObservedObject var document: Document
    @State private var showingFlashcards = false
    
    var body: some View {
        List {
            Section(header: Text("Document")) {
                DocumentRow(document: document, showPreview: false)
            }
            
            Section(header: Text("Study Options")) {
                Button("Review Flashcards") {
                    showingFlashcards = true
                }
            }
        }
        .navigationTitle("Study")
        .sheet(isPresented: $showingFlashcards) {
            NavigationView {
                FlashcardView(question: document.flashcards.first?.question ?? "",
                             answer: document.flashcards.first?.answer ?? "No flashcards available")
                    .navigationTitle("Flashcards")
                    .navigationBarItems(trailing: Button("Done") {
                        showingFlashcards = false
                    })
            }
        }
    }
}

#Preview {
    StudyView(document: Document(
        source: .text("Sample content"),
        title: "Sample Document"
    ))
} 