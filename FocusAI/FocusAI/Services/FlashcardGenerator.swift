import Foundation

public protocol FlashcardGenerator {
    func generateFlashcards(from text: String, count: Int, difficulty: FlashcardDifficulty) async throws -> [Flashcard]
}

public class DefaultFlashcardGenerator: FlashcardGenerator {
    private let llmInterface: LLMInterface
    
    public init(llmInterface: LLMInterface) {
        self.llmInterface = llmInterface
    }
    
    public func generateFlashcards(from text: String, count: Int = 8, difficulty: FlashcardDifficulty = .intermediate) async throws -> [Flashcard] {
        // For now, use the LLM interface to generate basic flashcards
        // In a real implementation, this would format the prompt based on difficulty
        let baseFlashcards = try await llmInterface.generateFlashcards(text: text)
        
        // Adjust flashcards based on difficulty and count
        let adjustedFlashcards = adjustFlashcardsForDifficulty(baseFlashcards, difficulty: difficulty)
        
        // Return the requested number of flashcards
        return Array(adjustedFlashcards.prefix(count))
    }
    
    private func adjustFlashcardsForDifficulty(_ flashcards: [Flashcard], difficulty: FlashcardDifficulty) -> [Flashcard] {
        return flashcards.map { flashcard in
            var adjusted = flashcard
            
            switch difficulty {
            case .beginner:
                adjusted.tags.append("beginner")
                // Beginner flashcards tend to be more direct and simple
                
            case .intermediate:
                adjusted.tags.append("intermediate")
                // Intermediate flashcards balance detail with clarity
                
            case .advanced:
                adjusted.tags.append("advanced")
                // Advanced flashcards can be more complex and nuanced
            }
            
            return adjusted
        }
    }
} 