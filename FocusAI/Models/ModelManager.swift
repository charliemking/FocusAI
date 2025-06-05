import Foundation
import MLCChat
import os.log

class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var isModelLoaded = false
    private var llmWrapper: LLMWrapper?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "ModelManager")
    
    private init() {}
    
    func loadModel() async throws {
        do {
            llmWrapper = try LLMWrapper()
            await MainActor.run {
                isModelLoaded = true
            }
            logger.info("Successfully loaded ML model")
        } catch {
            logger.error("Failed to load ML model: \(error.localizedDescription)")
            throw error
        }
    }
    
    func generateSummary(from text: String) async throws -> String {
        guard let llm = llmWrapper else {
            throw ModelError.modelNotInitialized
        }
        
        let prompt = """
        Please provide a concise summary of the following text. Focus on the main points and key takeaways:

        \(text)

        Summary:
        """
        
        return try await llm.generate(prompt: prompt)
    }
    
    func generateFlashcards(from text: String) async throws -> [Flashcard] {
        guard let llm = llmWrapper else {
            throw ModelError.modelNotInitialized
        }
        
        let prompt = """
        Create a set of flashcards from the following text. Each flashcard should have a question and answer format. Focus on key concepts and important details:

        \(text)

        Format each flashcard as "Q: [question] A: [answer]", with each flashcard on a new line.
        """
        
        let response = try await llm.generate(prompt: prompt)
        return parseFlashcards(from: response)
    }
    
    func answerQuestion(_ question: String, using context: String) async throws -> String {
        guard let llm = llmWrapper else {
            throw ModelError.modelNotInitialized
        }
        
        let prompt = """
        Using the following context, please answer the question. If the answer cannot be found in the context, say so:

        Context:
        \(context)

        Question: \(question)

        Answer:
        """
        
        return try await llm.generate(prompt: prompt)
    }
    
    private func parseFlashcards(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty { continue }
            
            let parts = line.split(separator: "A:", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            
            let question = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "Q:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let answer = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !question.isEmpty && !answer.isEmpty {
                flashcards.append(Flashcard(question: question, answer: answer))
            }
        }
        
        return flashcards
    }
}

enum ModelError: LocalizedError {
    case modelNotInitialized
    
    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "ML model has not been initialized"
        }
    }
} 