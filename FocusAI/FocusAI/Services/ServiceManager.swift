import Foundation
import PDFKit

public enum LLMBackend {
    case ollama
    case stub
}

public class ServiceManager: ObservableObject {
    // MARK: - Services
    public let llmInterface: LLMInterface
    public let documentProcessor: DocumentProcessor
    public let flashcardGenerator: FlashcardGenerator
    public let backend: LLMBackend
    
    // MARK: - State
    @Published public var isInitialized = false
    @Published public var isProcessing = false
    @Published public var lastError: Error?
    @Published public var modelStatus: String = "Not loaded"
    
    // MARK: - Initialization
    
    public init(useStubServices: Bool = false, backend: LLMBackend = .ollama) {
        self.backend = backend
        print("🔧 ServiceManager init called with useStubServices: \(useStubServices), backend: \(backend)")
        
        if useStubServices {
            // Use stub implementations for development
            print("🔧 Using stub services for development")
            self.llmInterface = StubLLMInterface()
            self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
            self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
            self.modelStatus = "Stub mode"
        } else {
            switch backend {
            case .ollama:
                // Use Ollama implementation (fast and reliable)
                print("🔧 Attempting to use Ollama services")
                self.llmInterface = OllamaLLMInterface()
                self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
                self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
                self.modelStatus = "Connecting to Ollama..."
                
            case .stub:
                // This case shouldn't happen since useStubServices would be true
                print("🔧 Using stub services (fallback)")
                self.llmInterface = StubLLMInterface()
                self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
                self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
                self.modelStatus = "Stub mode"
            }
        }
        
        print("🔧 ServiceManager initialization complete")
    }
    
    // MARK: - Initialization Methods
    
    public func initializeServices() async {
        guard !isInitialized else {
            print("✅ Services already initialized")
            return
        }
        
        print("🔄 Initializing services...")
        
        do {
            await MainActor.run {
                self.isProcessing = true
                self.modelStatus = "Loading model..."
            }
            
            try await llmInterface.loadModel()
            
            await MainActor.run {
                self.isInitialized = true
                self.isProcessing = false
                self.modelStatus = "Model loaded successfully"
                print("✅ All services initialized successfully")
            }
        } catch {
            await MainActor.run {
                self.lastError = error
                self.isProcessing = false
                self.modelStatus = "Failed to load model"
                print("❌ Service initialization failed: \(error)")
            }
        }
    }
    
    // MARK: - Processing Methods
    
    public func processDocument(pdf: PDFDocument) async throws -> ProcessedDocument {
        print("📄 Processing PDF document...")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        do {
            let document = try await documentProcessor.processDocument(pdf: pdf)
            print("✅ PDF processed successfully: \(document.title)")
            return document
        } catch {
            print("❌ PDF processing failed: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func processDocument(url: URL) async throws -> ProcessedDocument {
        print("🌐 Processing URL: \(url.absoluteString)")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        do {
            let document = try await documentProcessor.processDocument(url: url)
            print("✅ URL processed successfully: \(document.title)")
            return document
        } catch {
            print("❌ URL processing failed: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func processText(_ text: String) async throws -> ProcessedDocument {
        print("📝 Processing text input (\(text.count) characters)...")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        do {
            let document = try await documentProcessor.processDocument(text: text)
            print("✅ Text processed successfully: \(document.title)")
            return document
        } catch {
            print("❌ Text processing failed: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        print("❓ Answering question: \(question.prefix(50))...")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        do {
            let answer = try await llmInterface.askQuestion(question, context: context)
            print("✅ Question answered successfully")
            return answer
        } catch {
            print("❌ Question answering failed: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func generateFlashcards(from text: String, count: Int = 6, difficulty: FlashcardDifficulty = .intermediate) async throws -> [Flashcard] {
        print("🃏 Generating \(count) flashcards at \(difficulty.rawValue) level...")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        do {
            let flashcards = try await flashcardGenerator.generateFlashcards(from: text, count: count, difficulty: difficulty)
            print("✅ Generated \(flashcards.count) flashcards successfully")
            return flashcards
        } catch {
            print("❌ Flashcard generation failed: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    // MARK: - Utility Methods
    
    public func clearLastError() {
        lastError = nil
    }
    
    public func getModelStatus() -> String {
        if isProcessing {
            return "Processing..."
        } else if isInitialized {
            return "Ready"
        } else {
            return modelStatus
        }
    }
    
    // MARK: - Test Method
    
    public func testModelCapabilities() async {
        print("🧪 Testing enhanced model capabilities...")
        
        let testText = """
        Machine learning is a method of data analysis that automates analytical model building. 
        It is a branch of artificial intelligence based on the idea that systems can learn from data, 
        identify patterns and make decisions with minimal human intervention. Machine learning algorithms 
        build a model based on sample data, known as training data, in order to make predictions or 
        decisions without being explicitly programmed to do so.
        """
        
        do {
            // Test summary generation
            print("📊 Testing summary generation...")
            let summary = try await llmInterface.generateSummary(text: testText)
            print("✅ Summary: \(summary.prefix(100))...")
            
            // Test Q&A
            print("❓ Testing question answering...")
            let answer = try await llmInterface.askQuestion("What is machine learning?", context: testText)
            print("✅ Answer: \(answer.prefix(100))...")
            
            // Test flashcard generation
            print("🃏 Testing flashcard generation...")
            let flashcards = try await llmInterface.generateFlashcards(text: testText)
            print("✅ Generated \(flashcards.count) flashcards")
            for (i, card) in flashcards.enumerated() {
                print("   Card \(i+1): \(card.question)")
            }
            
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
}
