import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

public struct PDFView: View {
    @State private var selectedPDF: PDFDocument?
    @State private var summary: String = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question: String = ""
    @State private var isShowingPicker = false
    @State private var isDragging = false
    @State private var isProcessing = false
    @State private var errorAlert: ErrorAlert?
    
    private let processor = DefaultDocumentProcessor()
    private let llm = StubLLMInterface()
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - PDF viewer
            VStack {
                if let pdf = selectedPDF {
                    PDFKitView(document: pdf)
                        .overlay(
                            VStack {
                                Button("Change PDF") {
                                    isShowingPicker = true
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                
                                if isProcessing {
                                    Text("Processing PDF...")
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(),
                            alignment: .topTrailing
                        )
                } else {
                    dropZoneView
                }
            }
            .frame(minWidth: 400)
            
            // Right side - Summary and Q&A
            VStack {
                // Summary section
                GroupBox("Summary") {
                    if isProcessing {
                        processingView
                    } else {
                        Text(summary.isEmpty ? "Summary will appear here" : summary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Flashcards section
                GroupBox("Flashcards") {
                    if isProcessing {
                        processingView
                    } else if flashcards.isEmpty {
                        Text("Flashcards will appear here")
                            .foregroundColor(.gray)
                    } else {
                        List(flashcards) { card in
                            VStack(alignment: .leading) {
                                Text("Q: \\(card.question)")
                                    .font(.headline)
                                Text("A: \\(card.answer)")
                                    .font(.body)
                            }
                        }
                    }
                }
                
                // Q&A section
                GroupBox("Ask a Question") {
                    TextField("Type your question...", text: $question)
                    Button("Ask") {
                        // TODO: Implement question handling
                    }
                    .disabled(selectedPDF == nil || isProcessing)
                }
            }
            .frame(minWidth: 300)
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleSelectedFile(result)
        }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var processingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)
            Text("Processing...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
    
    private var dropZoneView: some View {
        VStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundColor(isDragging ? .accentColor : .gray)
            Text("Drop PDF here or click to select")
                .foregroundColor(isDragging ? .accentColor : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(isDragging ? .accentColor : .gray)
                .padding()
        )
        .onTapGesture {
            isShowingPicker = true
        }
        .onDrop(
            of: [.pdf],
            delegate: PDFDropDelegate(
                isDragging: $isDragging,
                handleSelectedURL: handleDroppedFile
            )
        )
    }
    
    private func handleSelectedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Get security scoped access to the file
            guard url.startAccessingSecurityScopedResource() else {
                showError(title: "Access Error", message: "Could not access the selected PDF file.")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Copy the file to our app's documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove any existing file
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("Successfully copied file to: \\(destinationURL)")
                
                // Handle the copied file
                handleDroppedFile(destinationURL)
            } catch {
                print("Error copying file: \\(error)")
                showError(title: "File Error", message: "Could not copy the selected PDF file: \\(error.localizedDescription)")
            }
            
        case .failure(let error):
            print("File picker error: \\(error)")
            showError(title: "Error Selecting PDF", message: error.localizedDescription)
        }
    }
    
    private func handleDroppedFile(_ url: URL) {
        print("Attempting to load PDF from URL: \\(url)")
        print("File exists at path: \\(FileManager.default.fileExists(atPath: url.path))")
        print("File size: \\((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0) bytes")
        
        // Try to read the file data first
        do {
            let data = try Data(contentsOf: url)
            print("Successfully read \\(data.count) bytes of data")
            
            // Try creating PDFDocument from data first
            if let document = PDFDocument(data: data) {
                print("Successfully created PDF document from data")
                processPDFDocument(document)
                return
            } else {
                print("Failed to create PDF document from data, trying URL method...")
            }
        } catch {
            print("Error reading file data: \\(error)")
        }
        
        // Fallback to URL method
        if let document = PDFDocument(url: url) {
            print("Successfully created PDF document from URL")
            processPDFDocument(document)
        } else {
            print("Failed to create PDF document from URL")
            showError(title: "Invalid PDF", message: "Could not open the file as a PDF. Please make sure it's a valid PDF document.")
        }
    }
    
    private func processPDFDocument(_ document: PDFDocument) {
        guard document.pageCount > 0 else {
            print("PDF document has no pages")
            showError(title: "Empty PDF", message: "The PDF document appears to be empty.")
            return
        }
        
        print("Successfully loaded PDF with \\(document.pageCount) pages")
        
        selectedPDF = document
        isProcessing = true
        summary = ""
        flashcards = []
        
        // Process the PDF
        Task {
            do {
                print("Starting PDF text extraction")
                let text = try await processor.extractText(from: document)
                print("Extracted \\(text.count) characters of text")
                
                print("Generating summary")
                summary = try await llm.generateSummary(text: text)
                
                print("Generating flashcards")
                flashcards = try await llm.generateFlashcards(text: text)
                
                print("PDF processing completed successfully")
            } catch {
                print("Error during PDF processing: \\(error)")
                showError(title: "Processing Error", message: "Failed to process the PDF: \\(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    private func showError(title: String, message: String) {
        errorAlert = ErrorAlert(title: title, message: message)
    }
}

struct PDFDropDelegate: DropDelegate {
    @Binding var isDragging: Bool
    let handleSelectedURL: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.pdf])
    }
    
    func dropEntered(info: DropInfo) {
        isDragging = true
    }
    
    func dropExited(info: DropInfo) {
        isDragging = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        
        guard let itemProvider = info.itemProviders(for: [.pdf]).first else { 
            print("No PDF item provider found")
            return false 
        }
        
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    print("Error loading dropped file: \\(error!.localizedDescription)")
                }
                return
            }
            
            guard let url = url else { 
                print("No URL provided for dropped file")
                return 
            }
            
            // Create a permanent copy in the app's documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let permanentUrl = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                // If a file with the same name exists, remove it first
                if FileManager.default.fileExists(atPath: permanentUrl.path) {
                    try FileManager.default.removeItem(at: permanentUrl)
                }
                
                try FileManager.default.copyItem(at: url, to: permanentUrl)
                
                DispatchQueue.main.async {
                    handleSelectedURL(permanentUrl)
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error copying dropped file: \\(error.localizedDescription)")
                }
            }
        }
        
        return true
    }
}

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFKit.PDFView, context: Context) {
        nsView.document = document
    }
}

#Preview {
    PDFView()
} 