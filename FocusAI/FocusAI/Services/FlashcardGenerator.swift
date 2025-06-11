import Foundation

public protocol FlashcardGenerator {
    func generateFlashcards(from text: String) async throws -> [Flashcard]
}

public class DefaultFlashcardGenerator: FlashcardGenerator {
    public init() {}
    
    public func generateFlashcards(from text: String) async throws -> [Flashcard] {
        // TODO: Implement flashcard generation logic
        return [
            Flashcard(
                question: "Sample Question",
                answer: "Sample Answer",
                tags: ["sample"]
            )
        ]
    }
} 