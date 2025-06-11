import Foundation

public struct Flashcard: Identifiable {
    public let id = UUID()
    public var question: String
    public var answer: String
    public var tags: [String]
    public var lastReviewed: Date?
    public var confidenceLevel: Int // 1-5 scale
    
    public init(question: String, answer: String, tags: [String] = []) {
        self.question = question
        self.answer = answer
        self.tags = tags
        self.confidenceLevel = 1
    }
} 