import Foundation
import Combine

@MainActor
class DocumentProcessor: ObservableObject {
    @Published var documents: [Document] = []
    @Published var isProcessing = false
    @Published var error: Error?
    
    private let modelManager = ModelManager.shared
    
    enum ProcessingError: LocalizedError {
        case modelUnavailable
        case processingFailed
        case documentEmpty
        
        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Language model is not available"
            case .processingFailed:
                return "Failed to process document"
            case .documentEmpty:
                return "Document contains no content to process"
            }
        }
    }
    
    init() {
        Task {
            await modelManager.initialize()
        }
    }
    
    func process(document: Document) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // First extract the content
            await document.process()
            
            // Add to managed documents
            if !documents.contains(where: { $0.id == document.id }) {
                documents.append(document)
            }
        } catch {
            self.error = error
        }
    }
    
    func generateSummary(for document: Document) async throws -> String {
        guard let content = document.content.nilIfEmpty else {
            throw ProcessingError.documentEmpty
        }
        
        return try await modelManager.performGeneration { llm in
            try await llm.generateSummary(text: content)
        }
    }
    
    func generateFlashcards(for document: Document, count: Int = 5) async throws -> [(question: String, answer: String)] {
        guard let content = document.content.nilIfEmpty else {
            throw ProcessingError.documentEmpty
        }
        
        return try await modelManager.performGeneration { llm in
            try await llm.generateFlashcards(text: content, count: count)
        }
    }
    
    func answerQuestion(_ question: String, using document: Document) async throws -> String {
        guard let content = document.content.nilIfEmpty else {
            throw ProcessingError.documentEmpty
        }
        
        return try await modelManager.performGeneration { llm in
            try await llm.answerQuestion(question: question, context: content)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
} 