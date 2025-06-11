import Foundation

public protocol LLMInterface {
    func askQuestion(_ question: String, context: String) async throws -> String
    func generateSummary(text: String) async throws -> String
    func generateFlashcards(text: String) async throws -> [Flashcard]
}

public class StubLLMInterface: LLMInterface {
    public init() {}
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        // TODO: Implement real LLM interaction
        return "This is a stub answer. Real LLM integration coming soon!"
    }
    
    public func generateSummary(text: String) async throws -> String {
        // TODO: Implement real summary generation
        return "This is a stub summary. Real LLM integration coming soon!"
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        // TODO: Implement real flashcard generation
        return [
            Flashcard(
                question: "What is FocusAI?",
                answer: "A privacy-first study assistant for macOS",
                tags: ["general"]
            )
        ]
    }
} 