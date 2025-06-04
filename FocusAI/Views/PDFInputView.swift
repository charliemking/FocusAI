import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFInputView: View {
    @State private var isShowingFilePicker = false
    @State private var selectedDocument: Document?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if let document = selectedDocument {
                    // PDF Preview
                    PDFService.shared.previewPDF(url: document.source.pdfURL!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Action Buttons
                    HStack {
                        Button("Generate Summary") {
                            // TODO: Implement ML summary generation
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Create Flashcards") {
                            // TODO: Implement ML flashcard generation
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Upload prompt
                    VStack(spacing: 20) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Upload a PDF")
                            .font(.title2)
                        
                        Text("Tap to select a PDF file to analyze")
                            .foregroundColor(.secondary)
                        
                        Button("Select PDF") {
                            isShowingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                if isProcessing {
                    ProgressView("Processing PDF...")
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("PDF Analysis")
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    do {
                        isProcessing = true
                        errorMessage = nil
                        
                        let urls = try result.get()
                        guard let url = urls.first else { return }
                        
                        // Create document from PDF
                        selectedDocument = try await PDFService.shared.createDocument(from: url)
                        
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    
                    isProcessing = false
                }
            }
        }
    }
}

// Helper extension to get PDF URL from DocumentSource
extension DocumentSource {
    var pdfURL: URL? {
        if case .pdf(let url) = self {
            return url
        }
        return nil
    }
}

#Preview {
    PDFInputView()
} 