import SwiftUI

public struct URLView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var urlString = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var answer = ""
    @State private var errorMessage: String?
    @State private var rotationAngle = 0.0
    @State private var isLoadingFlashcards = false
    @State private var currentDocumentText = ""
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Top row with Summary and Flashcards side by side
                HStack(spacing: 16) {
                    // Summary section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(Theme.titleStyle)
                            .foregroundColor(Theme.primaryColor)
                        if isProcessing {
                            processingView
                        } else if summary.isEmpty {
                            Text("Summary will appear here")
                                .font(Theme.bodyStyle)
                                .foregroundColor(Color(.darkGray))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ScrollView {
                                Text(summary)
                                    .font(Theme.bodyStyle)
                                    .foregroundColor(Color(.darkGray))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                            .font(Theme.titleStyle)
                            .foregroundColor(Theme.primaryColor)
                        
                        if isLoadingFlashcards {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating flashcards...")
                                    .font(.caption)
                                    .foregroundColor(Color(.darkGray))
                            }
                        } else if flashcards.isEmpty && !isProcessing {
                            VStack(spacing: 8) {
                                Text("Interactive flashcards will appear here")
                                    .font(Theme.bodyStyle)
                                    .foregroundColor(Color(.darkGray))
                                if !summary.isEmpty {
                                    Button("Generate Flashcards") {
                                        generateFlashcardsAsync()
                                    }
                                    .font(Theme.subtitleStyle)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.primaryColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        } else if !flashcards.isEmpty {
                            FlashcardView(flashcards: flashcards)
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
                
                // Bottom row with URL input and Q&A side by side
                HStack(spacing: 16) {
                    // Left side - URL input
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter URL", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                            .font(Theme.bodyStyle)
                            .foregroundColor(Color(.darkGray))
                        
                        Button("Process") {
                            Task {
                                await loadURL()
                            }
                        }
                        .font(Theme.buttonStyle)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(urlString.isEmpty || isProcessing)
                        
                        Spacer()
                    }
                    .padding()
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
                        .font(Theme.buttonStyle)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(urlString.isEmpty || isProcessing)
                        
                        if !answer.isEmpty {
                            ScrollView {
                                Text(answer)
                                    .font(Theme.bodyStyle)
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
    }
    
    private var processingView: some View {
        VStack(spacing: 16) { // 12 * 1.33 ≈ 16
            // Custom spinning indicator (33% bigger)
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(Color(.darkGray), lineWidth: 5) // 4 * 1.33 ≈ 5
                .frame(width: 53, height: 53) // 40 * 1.33 ≈ 53
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            
            VStack(spacing: 5) { // 4 * 1.33 ≈ 5
                Text("Processing...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Color(.darkGray))
                
                Text("This may take 1-2 minutes")
                    .font(Theme.processingSubtitleStyle)
                    .foregroundColor(Color(.darkGray))
            }
        }
        .padding(27) // 20 * 1.33 ≈ 27
        .background(Color.white)
        .cornerRadius(16) // 12 * 1.33 ≈ 16
        .shadow(color: Color.black.opacity(0.2), radius: 11, x: 0, y: 5) // 8 * 1.33 ≈ 11, 4 * 1.33 ≈ 5
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private func loadURL() async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        flashcards = [] // Reset flashcards
        
        // Wait for services to be initialized
        while !serviceManager.isInitialized && serviceManager.lastError == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Check if initialization failed
        if let error = serviceManager.lastError {
            errorMessage = "Failed to initialize services: \(error.localizedDescription)"
            isProcessing = false
            return
        }
        
        do {
            let document = try await serviceManager.processDocument(url: url)
            currentDocumentText = document.content
            
            // Start both summary and flashcards in parallel
            async let summaryTask = serviceManager.llmInterface.generateSummary(text: document.content)
            async let _ = generateFlashcardsInBackground()
            
            // Wait for summary (faster, shows first)
            summary = try await summaryTask
            
            // Flashcards will complete in background and update UI automatically
        } catch {
            errorMessage = "Error loading URL: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func generateFlashcardsAsync() {
        guard !currentDocumentText.isEmpty else { return }
        
        Task {
            await MainActor.run {
                isLoadingFlashcards = true
            }
            
            do {
                let generatedFlashcards = try await serviceManager.flashcardGenerator.generateFlashcards(from: currentDocumentText, count: 5, difficulty: .intermediate)
                await MainActor.run {
                    flashcards = generatedFlashcards
                    isLoadingFlashcards = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error generating flashcards: \(error.localizedDescription)"
                    isLoadingFlashcards = false
                }
                print("❌ Flashcard generation error: \(error)")
            }
        }
    }
    
    private func generateFlashcardsInBackground() async {
        guard !currentDocumentText.isEmpty else { return }
        
        await MainActor.run {
            isLoadingFlashcards = true
        }
        
        do {
            let generatedFlashcards = try await serviceManager.flashcardGenerator.generateFlashcards(from: currentDocumentText, count: 5, difficulty: .intermediate)
            await MainActor.run {
                flashcards = generatedFlashcards
                isLoadingFlashcards = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error generating flashcards: \(error.localizedDescription)"
                isLoadingFlashcards = false
            }
            print("❌ Flashcard generation error: \(error)")
        }
    }
    
    private func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard !summary.isEmpty else {
            errorMessage = "Please process a URL first"
            return
        }
        
        // Wait for services to be initialized
        while !serviceManager.isInitialized && serviceManager.lastError == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Check if initialization failed
        if let error = serviceManager.lastError {
            errorMessage = "Failed to initialize services: \(error.localizedDescription)"
            return
        }
        
        do {
            let result = try await serviceManager.askQuestion(question, context: summary)
            answer = result
            print("🤖 Answer: \(result)")
        } catch {
            errorMessage = "Error asking question: \(error.localizedDescription)"
            print("❌ Question error: \(error)")
        }
    }
}

#Preview {
    URLView()
        .environmentObject(ServiceManager(useStubServices: true))
} 
