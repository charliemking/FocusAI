import Foundation
import CoreData
import PDFKit
import Combine

@MainActor
class DocumentProcessor: ObservableObject {
    static let shared = DocumentProcessor()
    
    @Published var isProcessing = false
    @Published var error: Error?
    private let modelManager = ModelManager.shared
    
    private init() {}
    
    func process(document: Document) async throws {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }
        
        try await document.process()
    }
    
    func generateSummary(for document: Document) async throws -> String {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }
        
        let summary = try await modelManager.generateSummary(from: document.content)
        try await document.saveSummary(summary)
        return summary
    }
    
    func generateFlashcards(for document: Document) async throws -> [Flashcard] {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }
        
        let cards = try await modelManager.generateFlashcards(from: document.content)
        try await document.saveFlashcards(cards)
        return cards
    }
    
    func answerQuestion(_ question: String, using document: Document) async throws -> String {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }
        
        return try await modelManager.answerQuestion(question, using: document.content)
    }
} 