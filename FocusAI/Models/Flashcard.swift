import Foundation

struct Flashcard: Codable, Identifiable {
    let id: UUID
    let question: String
    let answer: String
    
    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
} 