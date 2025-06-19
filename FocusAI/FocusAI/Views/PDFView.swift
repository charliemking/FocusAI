import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

public struct PDFView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var selectedPDF: PDFDocument?
    @State private var isDragging = false
    @State private var isShowingPicker = false
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var answer = ""
    @State private var errorAlert: ErrorAlert?
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Top row with Summary and Flashcards side by side
                HStack(spacing: 16) {
                    // Summary section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        if isProcessing {
                            processingView
                        } else {
                            Text(summary.isEmpty ? "Summary will appear here" : summary)
                                .foregroundColor(Color(.darkGray))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Flashcards section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flashcards")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        
                        if isProcessing {
                            processingView
                        } else if flashcards.isEmpty {
                            Text("Flashcards will appear here")
                                .foregroundColor(Color(.darkGray))
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(flashcards) { card in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Q: \(card.question)")
                                                .font(.headline)
                                                .foregroundColor(Color(.darkGray))
                                            Text("A: \(card.answer)")
                                                .font(.body)
                                                .foregroundColor(Color(.darkGray))
                                        }
                                        .padding(.vertical, 4)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
                .frame(height: (geometry.size.height - 48) / 2)
                
                // Bottom row with PDF viewer and Q&A side by side
                HStack(spacing: 16) {
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
                                            .foregroundColor(Theme.primaryColor)
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
                                            .foregroundColor(Theme.primaryColor)
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
                    .frame(width: (geometry.size.width - 48) * 0.25)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Right side - Q&A
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ask a Question")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        
                        TextField("Type your question...", text: $question)
                            .textFieldStyle(.plain)
                            .foregroundColor(Color(.darkGray))
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        
                        Button("Ask") {
                            Task {
                                await askQuestion()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(selectedPDF == nil || isProcessing)
                        
                        if !answer.isEmpty {
                            ScrollView {
                                Text(answer)
                                    .foregroundColor(Color(.darkGray))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                            }
                        } else {
                            Spacer()
                        }
                    }
                    .padding()
                    .frame(width: (geometry.size.width - 48) * 0.75)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
                .frame(height: (geometry.size.height - 48) / 2)
            }
            .padding(.vertical, 16)
            .background(Color(white: 0.95))
        }
        .fileImporter(
            isPresented: $isShowingPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
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
                .tint(Theme.primaryColor)
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
                .foregroundColor(isDragging ? Theme.primaryColor : .gray)
            Text("Drop PDF here or click to select")
                .foregroundColor(isDragging ? Theme.primaryColor : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10])
                )
                .foregroundColor(isDragging ? Theme.primaryColor : .gray)
                .padding()
        )
        .background(Theme.lightAccent.opacity(isDragging ? 0.3 : 0))
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
        answer = ""
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
        // Start accessing the security-scoped resource if needed
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Try to read the file data first
            let data = try Data(contentsOf: url)
            
            // Create PDF document from data instead of URL
            guard let document = PDFDocument(data: data) else {
                errorAlert = ErrorAlert(
                    title: "Error",
                    message: "Failed to load PDF. Please make sure it's a valid PDF file."
                )
                return
            }
            
            // Set the document immediately so the user can work with it
            selectedPDF = document
            
            // Start processing the PDF automatically
            Task {
                await processPDF(document)
            }
            
            // Save a copy in the background
            DispatchQueue.global(qos: .background).async {
                do {
                    let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    let pdfDirectory = appSupportDirectory.appendingPathComponent("FocusAI/PDFs", isDirectory: true)
                    
                    try FileManager.default.createDirectory(at: pdfDirectory, withIntermediateDirectories: true)
                    let permanentUrl = pdfDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    // Save the data directly instead of copying the file
                    try data.write(to: permanentUrl)
                } catch {
                    // Just log the error since the PDF is already loaded and working
                    print("Failed to save PDF copy: \(error.localizedDescription)")
                }
            }
            
        } catch {
            errorAlert = ErrorAlert(
                title: "Error",
                message: "Error handling file: \(error.localizedDescription)"
            )
        }
    }
    
    private func processPDF(_ pdf: PDFDocument) async {
        isProcessing = true
        
        do {
            summary = try await serviceManager.llmInterface.generateSummary(text: extractTextFromPDF(pdf))
            flashcards = try await serviceManager.flashcardGenerator.generateFlashcards(from: extractTextFromPDF(pdf), count: 5, difficulty: .intermediate)
        } catch {
            errorAlert = ErrorAlert(
                title: "Processing Error",
                message: "Error processing PDF: \(error.localizedDescription)"
            )
            print("❌ PDF processing error: \(error)")
        }
        
        isProcessing = false
    }
    
    private func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let pdf = selectedPDF else {
            errorAlert = ErrorAlert(
                title: "No PDF",
                message: "Please load a PDF first"
            )
            return
        }
        
        do {
            let pdfText = extractTextFromPDF(pdf)
            let result = try await serviceManager.askQuestion(question, context: pdfText)
            answer = result
            print("🤖 Answer: \(result)")
        } catch {
            errorAlert = ErrorAlert(
                title: "Question Error", 
                message: "Error asking question: \(error.localizedDescription)"
            )
            print("❌ Question error: \(error)")
        }
    }
    
    private func extractTextFromPDF(_ pdf: PDFDocument) -> String {
        var text = ""
        for pageIndex in 0..<pdf.pageCount {
            if let page = pdf.page(at: pageIndex) {
                text += page.string ?? ""
                text += "\n"
            }
        }
        return text
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
        .environmentObject(ServiceManager(useStubServices: true))
} 
