import Foundation

public struct Flashcard: Identifiable, Codable {
    public let id: UUID
    public var question: String
    public var answer: String
    public var tags: [String]
    public var lastReviewed: Date?
    public var confidenceLevel: Int // 1-5 scale
    
    public init(question: String, answer: String, tags: [String] = []) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.tags = tags
        self.confidenceLevel = 1
    }
}

public enum FlashcardDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    public var description: String {
        return rawValue
    }
}

public struct ProcessedDocument {
    public let id: UUID
    public let title: String
    public let content: String
    public let summary: String
    public let flashcards: [Flashcard]
    public let wordCount: Int
    public let processedAt: Date
    public let sourceType: DocumentSourceType
    
    public init(title: String, content: String, summary: String, flashcards: [Flashcard] = [], sourceType: DocumentSourceType) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.summary = summary
        self.flashcards = flashcards
        self.wordCount = content.split(separator: " ").count
        self.processedAt = Date()
        self.sourceType = sourceType
    }
}

public enum DocumentSourceType: String, CaseIterable {
    case text = "Text"
    case pdf = "PDF"
    case url = "URL"
    
    public var description: String {
        return rawValue
    }
} 
