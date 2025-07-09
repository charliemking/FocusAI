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
        // Try to generate the requested number of flashcards
        var baseFlashcards = try await llmInterface.generateFlashcards(text: text, count: count)
        
        // If we didn't get enough flashcards, try to generate more
        if baseFlashcards.count < count {
            print("⚠️ Only got \(baseFlashcards.count) flashcards, requested \(count). Trying to generate more...")
            
            // Try generating with a higher count to get more options
            let additionalFlashcards = try await llmInterface.generateFlashcards(text: text, count: count + 5)
            
            // Use the additional flashcards if we got more
            if additionalFlashcards.count > baseFlashcards.count {
                baseFlashcards = additionalFlashcards
            }
        }
        
        // Adjust flashcards based on difficulty
        let adjustedFlashcards = adjustFlashcardsForDifficulty(baseFlashcards, difficulty: difficulty)
        
        // Return the requested number of flashcards (or what we have if less)
        let targetCount = min(count, adjustedFlashcards.count)
        return Array(adjustedFlashcards.prefix(targetCount))
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