import SwiftUI

public struct TextView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var summary = ""
    @State private var flashcards: [Flashcard] = []
    @State private var question = ""
    @State private var answer = ""
    @State private var errorMessage: String?
    @State private var summaryRotationAngle = 0.0
    @State private var flashcardRotationAngle = 0.0
    @State private var isLoadingFlashcards = false
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
                                .foregroundColor(Color(.darkGray))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            ScrollView {
                                Text(summary)
                                    .font(Theme.bodyStyle)
                                    .foregroundColor(Color(.darkGray))
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
                    VStack(alignment: .leading, spacing: 0) {
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
                                    .foregroundColor(.secondary)
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
                                    .foregroundColor(Color(.darkGray))
                                
                                if !summary.isEmpty {
                                    Button("Generate Flashcards") {
                                        flashcardTask = Task {
                                            await generateFlashcardsInBackground()
                                        }
                                    }
                                    .font(Theme.subtitleStyle)
                                    .foregroundColor(.white)
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
                
                // Bottom row with text input and Q&A side by side
                HStack(spacing: 16) {
                    // Left side - Text input
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $inputText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .scrollContentBackground(.hidden)
                            .background(Color.white)
                            .foregroundColor(Color(.darkGray))
                            .accentColor(Color(.darkGray))
                            .font(Theme.bodyStyle)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .padding(4)
                        
                        Button("Process") {
                            Task {
                                await processText()
                            }
                        }
                        .font(Theme.buttonStyle)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryColor)
                        .disabled(inputText.isEmpty || isProcessing)
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
                        .disabled(inputText.isEmpty || isProcessing)
                        
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
                .rotationEffect(.degrees(summaryRotationAngle))
                .onAppear {
                    startSummarySpinning()
                }
            
            VStack(spacing: 5) { // 4 * 1.33 ≈ 5
                Text("Processing...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Color(.darkGray))
                
                Text("This may take 30 seconds")
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
                .stroke(Color(.darkGray), lineWidth: 5)
                .frame(width: 53, height: 53)
                .rotationEffect(.degrees(flashcardRotationAngle))
                .onAppear {
                    startFlashcardSpinning()
                }
            
            VStack(spacing: 5) {
                Text("Generating flashcards...")
                    .font(Theme.processingTitleStyle)
                    .foregroundColor(Color(.darkGray))
                
                Text("Creating interactive study cards")
                    .font(Theme.processingSubtitleStyle)
                    .foregroundColor(Color(.darkGray))
            }
        }
        .padding(27)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 11, x: 0, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private func processText() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter some text to process"
            return
        }
        
        isProcessing = true
        errorMessage = nil
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
            errorMessage = "Failed to initialize services: \(error.localizedDescription)"
            isProcessing = false
            return
        }
        
        // Start both summary and flashcards in parallel
        async let summaryTask = serviceManager.llmInterface.generateSummary(text: inputText)
        
        // Start flashcard generation in background with proper task management
        flashcardTask = Task {
            await MainActor.run {
                isLoadingFlashcards = true
            }
            await generateFlashcardsInBackground()
        }
        
        do {
            // Wait for summary (faster, shows first)
            summary = try await summaryTask
        } catch {
            errorMessage = "Error generating summary: \(error.localizedDescription)"
            print("❌ Summary generation error: \(error)")
        }
        
        isProcessing = false
        
        // Flashcards will complete in background and update UI automatically
    }
    

    
    private func generateFlashcardsInBackground() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            await MainActor.run {
                isLoadingFlashcards = false
            }
            return 
        }
        
        do {
            // Check if task was cancelled before making the expensive LLM call
            try Task.checkCancellation()
            
            let generatedFlashcards = try await serviceManager.flashcardGenerator.generateFlashcards(from: inputText, count: 15, difficulty: .intermediate)
            
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
        
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter some text first"
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
            let result = try await serviceManager.askQuestion(question, context: inputText)
            answer = result
            print("🤖 Answer: \(result)")
        } catch {
            errorMessage = "Error asking question: \(error.localizedDescription)"
            print("❌ Question error: \(error)")
        }
    }
}

#Preview {
    TextView()
        .environmentObject(ServiceManager(useStubServices: true))
} 
