import Foundation
import PDFKit

public enum LLMBackend {
    case ollama
    case stub
}

public class ServiceManager: ObservableObject {
    // MARK: - Services
    public var llmInterface: LLMInterface
    public var documentProcessor: DocumentProcessor
    public var flashcardGenerator: FlashcardGenerator
    public let backend: LLMBackend
    
    // MARK: - State
    @Published public var isInitialized = false
    @Published public var isProcessing = false
    @Published public var lastError: Error?
    @Published public var modelStatus: String = "Not loaded"
    
    // MARK: - Initialization
    
    private static func isOllamaAvailable() -> Bool {
        // Quick synchronous check if Ollama is reachable
        let url = URL(string: "http://localhost:11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0 // Quick timeout
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAvailable = false
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isAvailable = true
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return isAvailable
    }
    
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
            // Check if Ollama is available immediately
            if ServiceManager.isOllamaAvailable() {
                print("🔧 Ollama detected during init - starting with Ollama services")
                self.llmInterface = OllamaLLMInterface()
                self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
                self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
                self.modelStatus = "Ready (Ollama)"
            } else {
                // Start with stubs and upgrade to Ollama when available
                print("🔧 Ollama not available during init - starting with stub services")
                self.llmInterface = StubLLMInterface()
                self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
                self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
                self.modelStatus = "Initializing..."
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
        
        await MainActor.run {
            self.isProcessing = true
            if self.llmInterface is OllamaLLMInterface {
                self.modelStatus = "Loading Ollama model..."
            } else {
                self.modelStatus = "Checking for Ollama..."
            }
        }
        
        // Only check for upgrade if we're not already using Ollama
        if !(llmInterface is OllamaLLMInterface) {
            await checkAndUpgradeToOllama()
        }
        
        do {
            try await llmInterface.loadModel()
            
            await MainActor.run {
                self.isInitialized = true
                self.isProcessing = false
                if self.llmInterface is OllamaLLMInterface {
                    self.modelStatus = "Ready (Ollama)"
                } else {
                    self.modelStatus = "Ready (Demo mode)"
                }
                print("✅ All services initialized successfully")
            }
        } catch {
            print("❌ Service initialization failed: \(error)")
            await MainActor.run {
                self.lastError = error
                self.isProcessing = false
                self.modelStatus = "Failed to initialize"
            }
        }
    }
    
    public func checkAndUpgradeToOllama() async {
        print("🔍 Checking upgrade to Ollama - current interface: \(type(of: llmInterface))")
        print("🔍 Is Ollama available: \(ServiceManager.isOllamaAvailable())")
        
        // Check if we can upgrade from stubs to Ollama
        if ServiceManager.isOllamaAvailable() && !(llmInterface is OllamaLLMInterface) {
            print("🔧 Ollama is now available - upgrading from stub services")
            
            await MainActor.run {
                self.modelStatus = "Upgrading to Ollama..."
            }
            
            // Upgrade to Ollama services
            let ollamaInterface = OllamaLLMInterface()
            
            do {
                print("🔄 Attempting to load Ollama model...")
                // Try to load the Ollama model
                try await ollamaInterface.loadModel()
                print("✅ Ollama model loaded successfully!")
                
                // Success! Upgrade the services
                print("🔄 Upgrading all services to use Ollama...")
                self.llmInterface = ollamaInterface
                self.documentProcessor = DefaultDocumentProcessor(llmInterface: ollamaInterface)
                self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: ollamaInterface)
                
                await MainActor.run {
                    self.modelStatus = "Ready (Ollama)"
                }
                
                print("✅ Successfully upgraded to Ollama services")
                print("🔍 New LLM interface type: \(type(of: self.llmInterface))")
            } catch {
                print("⚠️ Ollama is available but model failed to load: \(error)")
                await MainActor.run {
                    self.modelStatus = "Ready (Demo mode)"
                }
            }
        } else {
            if llmInterface is OllamaLLMInterface {
                print("✅ Already using Ollama interface")
            } else if !ServiceManager.isOllamaAvailable() {
                print("❌ Ollama is not available for upgrade")
            }
        }
    }
    
    // Method to manually refresh and check for Ollama (can be called after onboarding)
    public func refreshServices() async {
        print("🔄 Manually refreshing services...")
        await checkAndUpgradeToOllama()
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
        
        // Check if we can upgrade from stubs to Ollama before processing
        if !(llmInterface is OllamaLLMInterface) && ServiceManager.isOllamaAvailable() {
            print("🔄 Ollama became available - upgrading from stub services for this request")
            await checkAndUpgradeToOllama()
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
        
        // Check if we can upgrade from stubs to Ollama before answering
        if !(llmInterface is OllamaLLMInterface) && ServiceManager.isOllamaAvailable() {
            print("🔄 Ollama became available - upgrading from stub services for this request")
            await checkAndUpgradeToOllama()
        }
        
        do {
            let answer = try await llmInterface.askQuestion(question, context: context)
            print("✅ Question answered successfully")
            return answer
        } catch {
            print("❌ Question answering failed: \(error)")
            
            // If using Ollama and it fails, try falling back to stubs
            if llmInterface is OllamaLLMInterface {
                print("🔄 Ollama failed, attempting fallback to stub services...")
                
                do {
                    let stubInterface = StubLLMInterface()
                    try await stubInterface.loadModel()
                    
                    // Switch to stub services
                    self.llmInterface = stubInterface
                    self.documentProcessor = DefaultDocumentProcessor(llmInterface: stubInterface)
                    self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: stubInterface)
                    
                    await MainActor.run {
                        self.modelStatus = "Ready (Demo mode - Ollama unavailable)"
                    }
                    
                    // Try the question again with stubs
                    let answer = try await stubInterface.askQuestion(question, context: context)
                    print("✅ Successfully answered with stub fallback")
                    return answer
                } catch {
                    print("❌ Stub fallback also failed: \(error)")
                }
            }
            
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func generateFlashcards(from text: String, count: Int = 6, difficulty: FlashcardDifficulty = .intermediate) async throws -> [Flashcard] {
        print("🃏 Generating \(count) flashcards at \(difficulty.rawValue) level...")
        print("🔍 Current LLM interface type: \(type(of: llmInterface))")
        print("🔍 Current model status: \(modelStatus)")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Check if we can upgrade from stubs to Ollama before processing
        if !(llmInterface is OllamaLLMInterface) && ServiceManager.isOllamaAvailable() {
            print("🔄 Ollama became available - upgrading from stub services for this request")
            await checkAndUpgradeToOllama()
            print("🔍 After upgrade, LLM interface type: \(type(of: llmInterface))")
        }
        
        do {
            let flashcards = try await flashcardGenerator.generateFlashcards(from: text, count: count, difficulty: difficulty)
            print("✅ Generated \(flashcards.count) flashcards successfully using \(type(of: llmInterface))")
            return flashcards
        } catch {
            print("❌ Flashcard generation failed with \(type(of: llmInterface)): \(error)")
            
            // Try with stub interface as fallback BUT don't switch permanently
            if llmInterface is OllamaLLMInterface {
                print("🔄 Ollama failed, trying one-time stub fallback for flashcards...")
                
                do {
                    let stubInterface = StubLLMInterface()
                    try await stubInterface.loadModel()
                    
                    // Use stub ONLY for this one flashcard request
                    let tempGenerator = DefaultFlashcardGenerator(llmInterface: stubInterface)
                    let flashcards = try await tempGenerator.generateFlashcards(from: text, count: count, difficulty: difficulty)
                    print("✅ Stub fallback succeeded for flashcards")
                    return flashcards
                } catch {
                    print("❌ Stub fallback also failed: \(error)")
                }
            }
            
            await MainActor.run {
                self.lastError = error
            }
            throw error
        }
    }
    
    public func generateSummary(text: String) async throws -> String {
        print("📝 Generating summary for \(text.count) characters...")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Check if we can upgrade from stubs to Ollama before processing
        if !(llmInterface is OllamaLLMInterface) && ServiceManager.isOllamaAvailable() {
            print("🔄 Ollama became available - upgrading from stub services for this request")
            await checkAndUpgradeToOllama()
        }
        
        do {
            let summary = try await llmInterface.generateSummary(text: text)
            print("✅ Summary generated successfully")
            return summary
        } catch {
            print("❌ Summary generation failed: \(error)")
            
            // If using Ollama and it fails, try falling back to stubs
            if llmInterface is OllamaLLMInterface {
                print("🔄 Ollama failed, attempting fallback to stub services...")
                
                do {
                    let stubInterface = StubLLMInterface()
                    try await stubInterface.loadModel()
                    
                    // Switch to stub services
                    self.llmInterface = stubInterface
                    self.documentProcessor = DefaultDocumentProcessor(llmInterface: stubInterface)
                    self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: stubInterface)
                    
                    await MainActor.run {
                        self.modelStatus = "Ready (Demo mode - Ollama unavailable)"
                    }
                    
                    // Try the summary again with stubs
                    let summary = try await stubInterface.generateSummary(text: text)
                    print("✅ Successfully generated summary with stub fallback")
                    return summary
                } catch {
                    print("❌ Stub fallback also failed: \(error)")
                }
            }
            
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
            let flashcards = try await llmInterface.generateFlashcards(text: testText, count: 5)
            print("✅ Generated \(flashcards.count) flashcards")
            for (i, card) in flashcards.enumerated() {
                print("   Card \(i+1): \(card.question)")
            }
            
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
}
