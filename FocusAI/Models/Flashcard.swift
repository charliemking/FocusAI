import Foundation

struct Flashcard: Identifiable, Codable {
    let id: UUID
    let question: String
    let answer: String
    var lastReviewed: Date?
    var confidence: Confidence
    
    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
        self.confidence = .unknown
    }
    
    enum Confidence: Int, Codable {
        case unknown = 0
        case low = 1
        case medium = 2
        case high = 3
    }
} 