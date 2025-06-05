import Foundation
import MLCChat
import os.log

/// Handles all interactions with the local Mistral 7B model
class LLMWrapper {
    private let model: MLCChat
    private let settings: GenerationSettings
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "LLMWrapper")
    
    enum LLMError: LocalizedError {
        case initializationError
        case inferenceError(String)
        case tokenizationError
        case contextLengthExceeded
        case invalidModelPath
        
        var errorDescription: String? {
            switch self {
            case .initializationError:
                return "Failed to initialize the language model"
            case .inferenceError(let message):
                return "Error during text generation: \(message)"
            case .tokenizationError:
                return "Failed to process input text"
            case .contextLengthExceeded:
                return "Input text exceeds maximum context length"
            case .invalidModelPath:
                return "Model file not found at specified path"
            }
        }
    }
    
    init(modelPath: String? = nil, settings: GenerationSettings = ModelConfig.defaultGenerationSettings) throws {
        self.settings = settings
        
        let path = modelPath ?? ModelConfig.modelPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw LLMError.invalidModelPath
        }
        
        do {
            self.model = try MLCChat(modelPath: path)
            try configureModel()
            logger.info("Successfully initialized model at path: \(path)")
        } catch {
            logger.error("Failed to initialize model: \(error.localizedDescription)")
            throw LLMError.initializationError
        }
    }
    
    private func configureModel() throws {
        // Configure model parameters
        model.temperature = settings.temperature
        model.topP = settings.topP
        model.repetitionPenalty = settings.repetitionPenalty
        logger.debug("Configured model with temperature: \(settings.temperature), topP: \(settings.topP)")
    }
    
    /// Generates a summary of the provided text
    func generateSummary(text: String) async throws -> String {
        let prompt = """
        Please provide a concise summary of the following text:
        
        \(text)
        
        Summary:
        """
        return try await generate(prompt: prompt)
    }
    
    /// Generates flashcards from the provided text
    func generateFlashcards(text: String, count: Int = 5) async throws -> [(question: String, answer: String)] {
        let prompt = """
        Generate \(count) flashcard-style question and answer pairs from the following text:
        
        \(text)
        
        Format each pair as "Q: [question] A: [answer]", one per line.
        """
        
        let response = try await generate(prompt: prompt)
        return parseFlashcards(from: response)
    }
    
    /// Answers a specific question based on the provided context
    func answerQuestion(question: String, context: String) async throws -> String {
        let prompt = """
        Using only the following context, answer the question.
        
        Context:
        \(context)
        
        Question: \(question)
        
        Answer:
        """
        return try await generate(prompt: prompt)
    }
    
    /// Core generation method that handles the interaction with MLCChat
    private func generate(prompt: String) async throws -> String {
        // Check token count before processing
        let estimatedTokens = estimateTokenCount(prompt)
        if estimatedTokens > ModelConfig.contextWindow {
            logger.error("Input exceeds context window: \(estimatedTokens) tokens")
            throw LLMError.contextLengthExceeded
        }
        
        do {
            try await model.prefill(text: prompt)
            var response = ""
            var tokenCount = 0
            
            while !model.stopped() && tokenCount < settings.maxTokens {
                if let token = try await model.decode() {
                    response += token
                    tokenCount += 1
                }
            }
            
            logger.debug("Generated response with \(tokenCount) tokens")
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as MLCChat.Error {
            logger.error("MLCChat error: \(error.localizedDescription)")
            throw LLMError.inferenceError(error.localizedDescription)
        } catch {
            logger.error("Unknown error: \(error.localizedDescription)")
            throw LLMError.inferenceError("Unknown error occurred")
        }
    }
    
    /// Parses flashcard response into structured QA pairs
    private func parseFlashcards(from text: String) -> [(question: String, answer: String)] {
        let lines = text.components(separatedBy: .newlines)
        var flashcards: [(question: String, answer: String)] = []
        
        for line in lines {
            let parts = line.split(separator: "A:", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let question = parts[0].replacingOccurrences(of: "Q:", with: "").trimmingCharacters(in: .whitespaces)
                let answer = parts[1].trimmingCharacters(in: .whitespaces)
                flashcards.append((question, answer))
            }
        }
        
        return flashcards
    }
    
    /// Estimates token count for input text
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return text.count / 4
    }
} 