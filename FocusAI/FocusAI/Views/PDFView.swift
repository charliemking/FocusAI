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
    @State private var isDragging = false
    @State private var isShowingPicker = false
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var errorAlert: ErrorAlert?
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left side - PDF viewer
            VStack {
                if let pdf = selectedPDF {
                    ZStack(alignment: .topTrailing) {
                        PDFKitView(document: pdf)
                        
                        HStack(spacing: 8) {
                            Menu {
                                Button("Replace PDF") {
                                    isShowingPicker = true
                                }
                                
                                Button("Clear PDF", role: .destructive) {
                                    clearCurrentPDF()
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Theme.primaryBlue)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            
                            if isProcessing {
                                Text("Processing...")
                                    .font(.caption)
                                    .foregroundColor(Theme.primaryBlue)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                } else {
                    dropZoneView
                }
            }
            .frame(minWidth: 400)
            .background(Theme.backgroundWhite)
            
            // Right side - Summary and Q&A
            VStack(spacing: 16) {
                // Summary section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    if isProcessing {
                        processingView
                    } else {
                        Text(summary.isEmpty ? "Summary will appear here" : summary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .customGroupBox()
                
                // Flashcards section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flashcards")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    if isProcessing {
                        processingView
                    } else if flashcards.isEmpty {
                        Text("Flashcards will appear here")
                            .foregroundColor(.gray)
                    } else {
                        List(flashcards) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q: \(card.question)")
                                    .font(.headline)
                                Text("A: \(card.answer)")
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)
                    }
                }
                .customGroupBox()
                
                // Q&A section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask a Question")
                        .font(.headline)
                        .foregroundColor(Theme.primaryBlue)
                    
                    TextField("Type your question...", text: $question)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Ask") {
                        // TODO: Implement question handling
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryBlue)
                    .disabled(selectedPDF == nil || isProcessing)
                }
                .customGroupBox()
            }
            .frame(minWidth: 300)
            .padding()
            .background(Theme.backgroundWhite)
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
                .tint(Theme.primaryBlue)
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
                .foregroundColor(isDragging ? Theme.primaryBlue : .gray)
            Text("Drop PDF here or click to select")
                .foregroundColor(isDragging ? Theme.primaryBlue : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10])
                )
                .foregroundColor(isDragging ? Theme.primaryBlue : .gray)
                .padding()
        )
        .background(Theme.lightBlue.opacity(isDragging ? 0.3 : 0))
        .animation(.easeInOut(duration: 0.2), value: isDragging)
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
    
    private func clearCurrentPDF() {
        selectedPDF = nil
        summary = ""
        flashcards = []
        question = ""
    }
    
    private func handleSelectedFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            handleDroppedFile(url)
        } catch {
            errorAlert = ErrorAlert(
                title: "Error",
                message: "Failed to load PDF: \(error.localizedDescription)"
            )
        }
    }
    
    private func handleDroppedFile(_ url: URL) {
        guard let document = PDFDocument(url: url) else {
            errorAlert = ErrorAlert(
                title: "Error",
                message: "Failed to load PDF. Please make sure it's a valid PDF file."
            )
            return
        }
        
        selectedPDF = document
        // TODO: Process the PDF content
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