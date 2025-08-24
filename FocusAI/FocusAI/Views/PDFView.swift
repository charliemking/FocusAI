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
    @State private var errorMessage: String?
    @State private var summaryRotationAngle = 0.0
    @State private var flashcardRotationAngle = 0.0
    @State private var isLoadingFlashcards = false
    @State private var isLoadingAnswer = false
    @State private var currentPDFText = ""
    @State private var flashcardTask: Task<Void, Never>?
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Top row with Summary and Flashcards side by side
                HStack(spacing: 16) {
                    // Summary section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Summary")
                                .font(Theme.titleStyle)
                                .foregroundColor(Theme.primaryColor)
                            
                            Spacer()
                        }
                        
                        if isProcessing {
                            processingView
                        } else if summary.isEmpty {
                            Text("Summary will appear here")
                                .font(Theme.bodyStyle)
                                .foregroundColor(Theme.adaptiveTextColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            ScrollView {
                                Text(summary)
                                    .font(Theme.bodyStyle)
                                    .foregroundColor(Theme.adaptiveTextColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Theme.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Flashcards section
                    VStack(alignment: .leading, spacing: 4) {
                        // Always show title
                        HStack {
                            Text("Flashcards")
                                .font(Theme.titleStyle)
                                .foregroundColor(Theme.primaryColor)
                            
                            Spacer()
                            
                            // Show count in corner when flashcards exist
                            if !flashcards.isEmpty {
                                Text("\(flashcards.count) cards")
                                    .font(.caption)
                                    .foregroundColor(Theme.adaptiveTextColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if isLoadingFlashcards {
                            flashcardLoadingView
                        } else if flashcards.isEmpty && !isProcessing {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Interactive flashcards will appear here")
                                    .font(Theme.bodyStyle)
                                    .foregroundColor(Theme.adaptiveTextColor)
                                
                                if !summary.isEmpty {
                                    Button("Generate Flashcards") {
                                        flashcardTask = Task {
                                            await generateFlashcardsInBackground()
                                        }
                                    }
                                    .font(Theme.subtitleStyle)
                                    .foregroundColor(Color(NSColor.controlBackgroundColor))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.primaryColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else if !flashcards.isEmpty {
                            FlashcardView(flashcards: flashcards)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            .font(Theme.titleStyle)
                            .foregroundColor(Theme.primaryColor)
                        
                        TextField("Type your question...", text: $question)
                            .textFieldStyle(.plain)
                            .font(Theme.bodyStyle)
                            .foregroundColor(Theme.adaptiveTextColor)
                            .padding(8)
                            .background(Theme.backgroundWhite)
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
                        .font(Theme.buttonStyle)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(isProcessing || isLoadingAnswer)
                        
                        // Fixed height container to prevent resizing during loading
                        VStack {
                            if isLoadingAnswer {
                                answerLoadingView
                            } else if !answer.isEmpty {
                                ScrollView {
                                    Text(answer)
                                        .font(Theme.bodyStyle)
                                        .foregroundColor(Theme.adaptiveTextColor)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 8)
                                }
                            } else {
                                Spacer()
                            }
                        }
                        .frame(minHeight: 120) // Minimum height to prevent layout jumps
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
        VStack(spacing: 16) { // 12 * 1.33 ≈ 16
            // Custom spinning indicator (33% bigger)
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(Theme.adaptiveTextColor, lineWidth: 5) // 4 * 1.33 ≈ 5
                .frame(width: 53, height: 53) // 40 * 1.33 ≈ 53
                .rotationEffect(.degrees(summaryRotationAngle))
                .onAppear {
                    startSummarySpinning()
                }
            
            VStack(spacing: 5) { // 4 * 1.33 ≈ 5
                Text("Processing...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
                
                Text("Creating comprehensive summary")
                    .font(Theme.processingSubtitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
            }
        }
        .padding(27) // 20 * 1.33 ≈ 27
        .background(Theme.backgroundWhite)
        .cornerRadius(16) // 12 * 1.33 ≈ 16
        .shadow(color: Color.black.opacity(0.2), radius: 11, x: 0, y: 5) // 8 * 1.33 ≈ 11, 4 * 1.33 ≈ 5
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private func startSummarySpinning() {
        summaryRotationAngle = 0
        withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            summaryRotationAngle = 360
        }
    }
    
    private func startFlashcardSpinning() {
        flashcardRotationAngle = 0
        withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            flashcardRotationAngle = 360
        }
    }
    
    private var flashcardLoadingView: some View {
        VStack(spacing: 16) {
            // Custom spinning indicator matching the processing view style exactly
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(Theme.adaptiveTextColor, lineWidth: 5)
                .frame(width: 53, height: 53)
                .rotationEffect(.degrees(flashcardRotationAngle))
                .onAppear {
                    startFlashcardSpinning()
                }
            
            VStack(spacing: 5) {
                Text("Generating flashcards...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
                
                Text("This may take 30 seconds")
                    .font(Theme.processingSubtitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
            }
        }
        .padding(27)
        .background(Theme.backgroundWhite)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 11, x: 0, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private var answerLoadingView: some View {
        VStack(spacing: 16) {
            // Custom spinning indicator matching the other loading views
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(Theme.adaptiveTextColor, lineWidth: 5)
                .frame(width: 53, height: 53)
                .rotationEffect(.degrees(summaryRotationAngle))
                .onAppear {
                    startSummarySpinning()
                }
            
            VStack(spacing: 5) {
                Text("Analyzing question...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
                
                Text("Answer will be ready in a moment")
                    .font(Theme.processingSubtitleStyle)
                    .foregroundColor(Theme.adaptiveTextColor)
            }
        }
        .padding(27)
        .background(Theme.backgroundWhite)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 11, x: 0, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
            
            // Safety check for file size (max 100MB)
            guard data.count < 100_000_000 else {
                errorAlert = ErrorAlert(
                    title: "File Too Large",
                    message: "PDF file is too large. Please select a file smaller than 100MB."
                )
                return
            }
            
            // Create PDF document from data instead of URL
            guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                errorAlert = ErrorAlert(
                    title: "Invalid PDF",
                    message: "Failed to load PDF. Please make sure it's a valid PDF file with readable content."
                )
                return
            }
            
            // Set the document immediately so the user can work with it
            selectedPDF = document
            
            // Start processing the PDF automatically with error handling
            Task {
                do {
                    await processPDF(document)
                } catch {
                    await MainActor.run {
                        errorAlert = ErrorAlert(
                            title: "Processing Error",
                            message: "Failed to process PDF: \(error.localizedDescription)"
                        )
                    }
                }
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
        flashcards = [] // Reset flashcards
        
        // Cancel any existing flashcard generation
        flashcardTask?.cancel()
        flashcardTask = nil
        
        // Wait for services to be initialized
        while !serviceManager.isInitialized && serviceManager.lastError == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Check if initialization failed
        if let error = serviceManager.lastError {
            errorAlert = ErrorAlert(
                title: "Service Error",
                message: "Failed to initialize services: \(error.localizedDescription)"
            )
            isProcessing = false
            return
        }
        
        do {
            let pdfText = extractTextFromPDF(pdf)
            currentPDFText = pdfText
            
            // Start both summary and flashcards in parallel
            async let summaryTask = serviceManager.generateSummary(text: pdfText)
            
            // Start flashcard generation in background with proper task management
            print("🔄 Starting flashcard generation task immediately")
            flashcardTask = Task {
                print("🔄 Inside flashcard task - setting isLoadingFlashcards = true")
                await MainActor.run {
                    isLoadingFlashcards = true
                }
                print("🔄 About to call generateFlashcardsInBackground")
                await generateFlashcardsInBackground()
            }
            
            // Wait for summary (faster, shows first)
            summary = try await summaryTask
            
            // Flashcards will complete in background and update UI automatically
        } catch {
            errorAlert = ErrorAlert(
                title: "Processing Error",
                message: "Error generating summary: \(error.localizedDescription)"
            )
            print("❌ Summary generation error: \(error)")
        }
        
        isProcessing = false
    }
    

    
    private func generateFlashcardsInBackground() async {
        print("🔄 generateFlashcardsInBackground called")
        guard !currentPDFText.isEmpty else { 
            print("🔄 PDF text is empty, stopping flashcard generation")
            await MainActor.run {
                isLoadingFlashcards = false
            }
            return 
        }
        
        print("🔄 About to make LLM call for flashcards")
        
        do {
            // Check if task was cancelled before making the expensive LLM call
            try Task.checkCancellation()
            
            let generatedFlashcards = try await serviceManager.generateFlashcards(from: currentPDFText, count: 15, difficulty: .intermediate)
            
            // Check again after the call in case it was cancelled during generation
            try Task.checkCancellation()
            
            await MainActor.run {
                flashcards = generatedFlashcards
                isLoadingFlashcards = false
            }
        } catch is CancellationError {
            // Task was cancelled, clean up UI state
            await MainActor.run {
                isLoadingFlashcards = false
            }
            print("🔄 Flashcard generation cancelled")
        } catch {
            await MainActor.run {
                errorAlert = ErrorAlert(
                    title: "Flashcard Error",
                    message: "Error generating flashcards: \(error.localizedDescription)"
                )
                isLoadingFlashcards = false
            }
            print("❌ Flashcard generation error: \(error)")
        }
    }
    
    private func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        
        // Wait for services to be initialized
        while !serviceManager.isInitialized && serviceManager.lastError == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Check if initialization failed
        if let error = serviceManager.lastError {
            errorAlert = ErrorAlert(
                title: "Service Error",
                message: "Failed to initialize services: \(error.localizedDescription)"
            )
            return
        }
        
        isLoadingAnswer = true
        
        do {
            // Use cached PDF text if available, otherwise use empty context for general questions
            let context = currentPDFText.isEmpty ? "" : currentPDFText
            let result = try await serviceManager.askQuestion(question, context: context)
            
            // Validate response is not empty
            let cleanedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedResult.isEmpty {
                errorAlert = ErrorAlert(
                    title: "No Response",
                    message: "The system didn't provide an answer. Please try rephrasing your question."
                )
            } else {
                answer = cleanedResult
            }
        } catch {
            errorAlert = ErrorAlert(
                title: "Question Error", 
                message: "Error asking question: \(error.localizedDescription)"
            )
        }
        
        isLoadingAnswer = false
    }
    
    private func extractTextFromPDF(_ pdf: PDFDocument) -> String {
        var text = ""
        let pageCount = pdf.pageCount
        
        // Safety check for reasonable page count
        guard pageCount > 0 && pageCount < 1000 else {
            print("⚠️ PDF has unusual page count: \(pageCount)")
            return ""
        }
        
        for pageIndex in 0..<pageCount {
            autoreleasepool {
                do {
                    if let page = pdf.page(at: pageIndex) {
                        let pageText = page.string ?? ""
                        text += pageText
                        text += "\n"
                    }
                } catch {
                    print("⚠️ Error extracting text from page \(pageIndex): \(error)")
                    // Continue with other pages
                }
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
