import Foundation
import PDFKit

public class ServiceManager: ObservableObject {
    // MARK: - Services
    public let llmInterface: LLMInterface
    public let documentProcessor: DocumentProcessor
    public let flashcardGenerator: FlashcardGenerator
    
    // MARK: - State
    @Published public var isInitialized = false
    @Published public var isProcessing = false
    @Published public var lastError: Error?
    
    // MARK: - Initialization
    
    public init(useStubServices: Bool = true) {
        print("🔧 ServiceManager init called with useStubServices: \(useStubServices)")
        
        if useStubServices {
            // Use stub implementations for development
            print("🔧 Using stub services for development")
            self.llmInterface = StubLLMInterface()
            self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
            self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
        } else {
            // Use real CoreML implementation
            print("🔧 Using real CoreML services")
            self.llmInterface = CoreMLLLMInterface()
            self.documentProcessor = DefaultDocumentProcessor(llmInterface: self.llmInterface)
            self.flashcardGenerator = DefaultFlashcardGenerator(llmInterface: self.llmInterface)
        }
        
        print("🔧 ServiceManager initialization complete")
    }
    
    // MARK: - Initialization Methods
    
    public func initialize() async {
        guard !isInitialized else { return }
        
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        do {
            try await llmInterface.loadModel()
            
            await MainActor.run {
                isInitialized = true
                isProcessing = false
            }
            
            print("✅ ServiceManager initialized successfully")
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error
            }
            
            print("❌ ServiceManager initialization failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Document Processing Methods
    
    public func processPDF(_ pdf: PDFDocument) async throws -> ProcessedDocument {
        return try await withProcessingState {
            try await documentProcessor.processDocument(pdf: pdf)
        }
    }
    
    public func processURL(_ url: URL) async throws -> ProcessedDocument {
        return try await withProcessingState {
            try await documentProcessor.processDocument(url: url)
        }
    }
    
    public func processText(_ text: String) async throws -> ProcessedDocument {
        return try await withProcessingState {
            try await documentProcessor.processDocument(text: text)
        }
    }
    
    // MARK: - Individual Service Methods
    
    public func generateSummary(from text: String) async throws -> String {
        return try await withProcessingState {
            try await llmInterface.generateSummary(text: text)
        }
    }
    
    public func generateFlashcards(from text: String, count: Int = 8, difficulty: FlashcardDifficulty = .intermediate) async throws -> [Flashcard] {
        return try await withProcessingState {
            try await flashcardGenerator.generateFlashcards(from: text, count: count, difficulty: difficulty)
        }
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        return try await withProcessingState {
            try await llmInterface.askQuestion(question, context: context)
        }
    }
    
    // MARK: - Utility Methods
    
    public func extractTextFromPDF(_ pdf: PDFDocument) async throws -> String {
        return try await withProcessingState {
            try await documentProcessor.extractText(from: pdf)
        }
    }
    
    public func extractTextFromURL(_ url: URL) async throws -> String {
        return try await withProcessingState {
            try await documentProcessor.extractText(from: url)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func withProcessingState<T>(_ operation: () async throws -> T) async throws -> T {
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        do {
            let result = try await operation()
            
            await MainActor.run {
                isProcessing = false
            }
            
            return result
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error
            }
            
            throw error
        }
    }
    
    // MARK: - Health Check
    
    public func performHealthCheck() async -> HealthCheckResult {
        var issues: [String] = []
        
        // Check LLM
        if !llmInterface.isModelLoaded() {
            issues.append("LLM model is not loaded")
        }
        
        // Check initialization
        if !isInitialized {
            issues.append("ServiceManager is not initialized")
        }
        
        return HealthCheckResult(
            isHealthy: issues.isEmpty,
            issues: issues,
            timestamp: Date()
        )
    }
}

// MARK: - Health Check Result

public struct HealthCheckResult {
    public let isHealthy: Bool
    public let issues: [String]
    public let timestamp: Date
    
    public var description: String {
        if isHealthy {
            return "✅ All services are healthy"
        } else {
            return "⚠️ Issues found:\n" + issues.map { "• \($0)" }.joined(separator: "\n")
        }
    }
} 
