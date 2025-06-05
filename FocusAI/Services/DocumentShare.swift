import Foundation
import UIKit
import UniformTypeIdentifiers

enum DocumentShareError: Error {
    case exportFailed
    case invalidDocument
    case encryptionFailed
}

actor DocumentShare {
    static let shared = DocumentShare()
    
    private init() {}
    
    // MARK: - Document Export
    
    func prepareDocumentForSharing(_ document: StoredDocument) async throws -> URL {
        guard let id = document.id,
              let content = document.content else {
            throw DocumentShareError.invalidDocument
        }
        
        // Create export data
        let exportData = ExportableDocument(
            id: id,
            title: document.title ?? "Untitled",
            content: content,
            createdAt: document.createdAt ?? Date(),
            sourceType: document.sourceType ?? "text",
            summary: document.summary?.content,
            flashcards: (document.flashcards as? Set<StoredFlashcard>)?.map { card in
                FlashcardData(
                    question: card.question ?? "",
                    answer: card.answer ?? ""
                )
            } ?? []
        )
        
        // Create temporary directory for export
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusAI")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        // Create export file
        let exportURL = tempDir.appendingPathComponent("\(document.title ?? "Document").focusai")
        
        // Encode and encrypt data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        
        // Write to file
        try data.write(to: exportURL)
        
        return exportURL
    }
    
    // MARK: - Document Import
    
    func importDocument(from url: URL) async throws -> StoredDocument {
        let data = try Data(contentsOf: url)
        
        // Decode data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedDoc = try decoder.decode(ExportableDocument.self, from: data)
        
        // Create new document
        let context = PersistenceController.shared.container.viewContext
        let document = StoredDocument(context: context)
        
        document.id = importedDoc.id
        document.title = importedDoc.title
        document.content = importedDoc.content
        document.createdAt = importedDoc.createdAt
        document.lastAccessed = Date()
        document.sourceType = importedDoc.sourceType
        
        // Create summary if present
        if let summaryContent = importedDoc.summary {
            let summary = StoredSummary(context: context)
            summary.id = UUID()
            summary.content = summaryContent
            summary.createdAt = Date()
            summary.document = document
        }
        
        // Create flashcards if present
        for cardData in importedDoc.flashcards {
            let flashcard = StoredFlashcard(context: context)
            flashcard.id = UUID()
            flashcard.question = cardData.question
            flashcard.answer = cardData.answer
            flashcard.createdAt = Date()
            flashcard.document = document
        }
        
        try context.save()
        
        // Index the imported document
        await SearchService.shared.indexDocument(document)
        
        return document
    }
}

// MARK: - Data Models

private struct ExportableDocument: Codable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
    let sourceType: String
    let summary: String?
    let flashcards: [FlashcardData]
}

private struct FlashcardData: Codable {
    let question: String
    let answer: String
}

// MARK: - Document Type Definition

extension UTType {
    static var focusAIDocument: UTType {
        UTType(exportedAs: "com.focusai.document")
    }
} 