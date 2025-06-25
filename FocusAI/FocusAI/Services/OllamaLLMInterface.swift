import Foundation
import OSLog

public class OllamaLLMInterface: LLMInterface {
    private let logger = Logger(subsystem: "com.focusai.app", category: "OllamaLLM")
    
    private let baseURL = "http://localhost:11434"
    private let modelName = "phi3:mini"
    private var isLoaded = false
    
    // MARK: - Performance Tracking
    private var performanceMetrics: [String: [Double]] = [:]
    
    public init() {
        logger.info("🔧 OllamaLLMInterface initialized")
    }
    
    // MARK: - LLMInterface Implementation
    
    public func loadModel() async throws {
        logger.info("🔄 Checking Ollama connection and model availability...")
        
        do {
            // Check if Ollama is running
            try await checkOllamaHealth()
            
            // Check if model is available, pull if needed
            try await ensureModelAvailable()
            
            // Test generation
            let testResponse = try await generateText(
                prompt: "Hello! Please respond with just 'Hi there!'",
                maxTokens: 10
            )
            
            guard !testResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.modelLoadFailed("Model test failed - no response")
            }
            
            isLoaded = true
            logger.info("✅ Ollama Phi-3 model loaded successfully")
            
        } catch {
            logger.error("❌ Failed to load Ollama model: \(error.localizedDescription)")
            throw LLMError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    public func isModelLoaded() -> Bool {
        return isLoaded
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildQuestionAnswerPrompt(question: question, context: context)
        let startTime = Date()
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 500)
            let duration = Date().timeIntervalSince(startTime)
            let cleanedResponse = cleanGeneratedText(response)
            
            recordPerformanceMetric("Question Answering", duration: duration, tokenCount: cleanedResponse.split(separator: " ").count)
            logger.info("✅ Question answered successfully in \(String(format: "%.2f", duration))s")
            return cleanedResponse
            
        } catch {
            logger.error("❌ Question answering failed: \(error)")
            throw error
        }
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildSummaryPrompt(text: text)
        let startTime = Date()
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 400)
            let duration = Date().timeIntervalSince(startTime)
            let cleanedResponse = cleanGeneratedText(response)
            
            recordPerformanceMetric("Summary Generation", duration: duration, tokenCount: cleanedResponse.split(separator: " ").count)
            logger.info("✅ Summary generated successfully in \(String(format: "%.2f", duration))s")
            return cleanedResponse
            
        } catch {
            logger.error("❌ Summary generation failed: \(error)")
            throw error
        }
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildFlashcardPrompt(text: text)
        let startTime = Date()
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 1500)
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("🔍 Raw flashcard response (\(response.count) chars): \(String(response.prefix(200)))...")
            
            let flashcards = parseFlashcards(from: response)
            
            if flashcards.isEmpty {
                logger.warning("⚠️ No flashcards parsed, trying enhanced parsing...")
                let enhancedFlashcards = parseFlashcardsEnhanced(from: response)
                
                if !enhancedFlashcards.isEmpty {
                    recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
                    logger.info("✅ Generated \(enhancedFlashcards.count) flashcards (enhanced parsing) in \(String(format: "%.2f", duration))s")
                    return enhancedFlashcards
                }
                
                // Try regex-based parsing as final fallback
                logger.warning("⚠️ Enhanced parsing failed, trying regex parsing...")
                let regexFlashcards = parseFlashcardsWithRegex(from: response)
                
                if !regexFlashcards.isEmpty {
                    recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
                    logger.info("✅ Generated \(regexFlashcards.count) flashcards (regex parsing) in \(String(format: "%.2f", duration))s")
                    return regexFlashcards
                }
                
                throw LLMError.processingFailed("No flashcards could be parsed from response")
            }
            
            recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
            logger.info("✅ Generated \(flashcards.count) flashcards successfully in \(String(format: "%.2f", duration))s")
            return flashcards
            
        } catch {
            logger.error("❌ Flashcard generation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Ollama Communication
    
    private func checkOllamaHealth() async throws {
        let url = URL(string: "\(baseURL)/api/tags")!
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.modelLoadFailed("Ollama is not running. Please start Ollama first.")
        }
        
        logger.info("✅ Ollama is running")
    }
    
    private func ensureModelAvailable() async throws {
        // Check if model exists
        let listURL = URL(string: "\(baseURL)/api/tags")!
        let (data, _) = try await URLSession.shared.data(from: listURL)
        
        struct OllamaModelsResponse: Codable {
            let models: [OllamaModel]
        }
        
        struct OllamaModel: Codable {
            let name: String
        }
        
        let modelsResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        let hasModel = modelsResponse.models.contains { $0.name.hasPrefix(modelName) }
        
        if !hasModel {
            logger.info("📥 Model \(self.modelName) not found, pulling from Ollama...")
            try await pullModel()
        } else {
            logger.info("✅ Model \(self.modelName) is available")
        }
    }
    
    private func pullModel() async throws {
        let url = URL(string: "\(baseURL)/api/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest = ["name": modelName]
        request.httpBody = try JSONSerialization.data(withJSONObject: pullRequest)
        
        logger.info("📥 Pulling model \(self.modelName)... This may take a few minutes.")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.modelLoadFailed("Failed to pull model \(modelName)")
        }
        
        logger.info("✅ Model \(self.modelName) pulled successfully")
    }
    
    private func generateText(prompt: String, maxTokens: Int) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let generateRequest: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": maxTokens,
                "temperature": 0.7,
                "top_p": 0.9,
                "repeat_penalty": 1.1
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: generateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.processingFailed("Ollama request failed")
        }
        
        struct OllamaResponse: Codable {
            let response: String
            let done: Bool
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }
    
    // MARK: - Prompt Building
    
    private func buildQuestionAnswerPrompt(question: String, context: String) -> String {
        let truncatedContext = String(context.prefix(6000))
        
        return """
        <|system|>You are a helpful AI assistant that answers questions based on provided context. Be concise but comprehensive.<|end|>
        <|user|>Context: \(truncatedContext)

        Question: \(question)<|end|>
        <|assistant|>
        """
    }
    
    private func buildSummaryPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(3000))
        
        return """
        <|system|>You are a helpful AI assistant that creates concise, informative summaries. Focus on key points and main ideas.<|end|>
        <|user|>Please summarize this text:

        \(truncatedText)<|end|>
        <|assistant|>Here's a summary of the text:

        """
    }
    
    private func buildFlashcardPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(3000))
        
        return """
        <|system|>You are a flashcard creator. Create exactly 3-5 flashcards from the provided text. Use ONLY the Q: and A: format. Do not add any other text or explanations.<|end|>
        <|user|>Create flashcards from this text. Use this exact format:

        Q: [Question]
        A: [Answer]

        Text: \(truncatedText)<|end|>
        <|assistant|>Q: 
        """
    }
    
    // MARK: - Text Processing
    
    private func cleanGeneratedText(_ text: String) -> String {
        var cleaned = text
        
        // Remove common artifacts
        cleaned = cleaned.replacingOccurrences(of: "<|end|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|assistant|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|user|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|system|>", with: "")
        
        // Remove excessive whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    // MARK: - Flashcard Parsing
    
    private func parseFlashcards(from text: String) -> [Flashcard] {
        logger.info("🔍 Raw response to parse: \(text.prefix(500))...")
        
        let lines = text.components(separatedBy: .newlines)
        var flashcards: [Flashcard] = []
        var currentQuestion = ""
        var currentAnswer = ""
        var collectingAnswer = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.hasPrefix("Q:") {
                // Save previous flashcard if we have one
                if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
                    flashcards.append(Flashcard(
                        question: currentQuestion,
                        answer: currentAnswer,
                        tags: ["ai-generated", "ollama"]
                    ))
                    logger.info("✅ Parsed flashcard: Q: \(currentQuestion) | A: \(currentAnswer)")
                }
                
                currentQuestion = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = ""
                collectingAnswer = false
            } else if trimmedLine.hasPrefix("A:") {
                currentAnswer = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                collectingAnswer = true
            } else if collectingAnswer && !trimmedLine.hasPrefix("Q:") && !trimmedLine.hasPrefix("A:") {
                // This is a continuation of the answer
                if !currentAnswer.isEmpty {
                    currentAnswer += " " + trimmedLine
                } else {
                    currentAnswer = trimmedLine
                }
            }
        }
        
        // Add the last flashcard
        if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
            flashcards.append(Flashcard(
                question: currentQuestion,
                answer: currentAnswer,
                tags: ["ai-generated", "ollama"]
            ))
            logger.info("✅ Parsed final flashcard: Q: \(currentQuestion) | A: \(currentAnswer)")
        }
        
        logger.info("📚 Total flashcards parsed: \(flashcards.count)")
        return flashcards
    }
    
    private func parseFlashcardsEnhanced(from text: String) -> [Flashcard] {
        logger.info("🔍 Enhanced parsing of response...")
        
        // Enhanced parsing with more flexible patterns
        let questionPatterns = ["Q:", "Question:", "**Q:", "**Question:"]
        let answerPatterns = ["A:", "Answer:", "**A:", "**Answer:"]
        
        let lines = text.components(separatedBy: .newlines)
        var flashcards: [Flashcard] = []
        var currentQuestion = ""
        var currentAnswer = ""
        var collectingAnswer = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty { continue }
            
            if questionPatterns.contains(where: trimmedLine.hasPrefix) {
                // Save previous flashcard if we have one
                if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
                    flashcards.append(Flashcard(
                        question: currentQuestion,
                        answer: currentAnswer,
                        tags: ["ai-generated", "ollama"]
                    ))
                    logger.info("✅ Enhanced parsed flashcard: Q: \(currentQuestion) | A: \(currentAnswer)")
                }
                
                // Extract question
                for pattern in questionPatterns {
                    if trimmedLine.hasPrefix(pattern) {
                        currentQuestion = String(trimmedLine.dropFirst(pattern.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }
                currentAnswer = ""
                collectingAnswer = false
            } else if answerPatterns.contains(where: trimmedLine.hasPrefix) {
                // Extract answer
                for pattern in answerPatterns {
                    if trimmedLine.hasPrefix(pattern) {
                        currentAnswer = String(trimmedLine.dropFirst(pattern.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        collectingAnswer = true
                        break
                    }
                }
            } else if collectingAnswer && !questionPatterns.contains(where: trimmedLine.hasPrefix) && !answerPatterns.contains(where: trimmedLine.hasPrefix) {
                // This is a continuation of the answer
                if !currentAnswer.isEmpty {
                    currentAnswer += " " + trimmedLine
                } else {
                    currentAnswer = trimmedLine
                }
            }
        }
        
        // Add the last flashcard
        if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
            flashcards.append(Flashcard(
                question: currentQuestion,
                answer: currentAnswer,
                tags: ["ai-generated", "ollama"]
            ))
            logger.info("✅ Enhanced parsed final flashcard: Q: \(currentQuestion) | A: \(currentAnswer)")
        }
        
        logger.info("📚 Enhanced total flashcards parsed: \(flashcards.count)")
        return flashcards
    }
    
    private func parseFlashcardsWithRegex(from text: String) -> [Flashcard] {
        logger.info("🔍 Regex parsing of response...")
        
        var flashcards: [Flashcard] = []
        
        // Use regex to find Q: and A: patterns
        let pattern = #"Q:\s*([^\n]+(?:\n(?!Q:|A:)[^\n]+)*)\s*A:\s*([^\n]+(?:\n(?!Q:|A:)[^\n]+)*)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for match in matches {
                if match.numberOfRanges == 3 {
                    let questionRange = Range(match.range(at: 1), in: text)
                    let answerRange = Range(match.range(at: 2), in: text)
                    
                    if let questionRange = questionRange, let answerRange = answerRange {
                        let question = String(text[questionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let answer = String(text[answerRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !question.isEmpty && !answer.isEmpty {
                            flashcards.append(Flashcard(
                                question: question,
                                answer: answer,
                                tags: ["ai-generated", "ollama", "regex-parsed"]
                            ))
                            logger.info("✅ Regex parsed flashcard: Q: \(question) | A: \(answer)")
                        }
                    }
                }
            }
        } catch {
            logger.error("❌ Regex parsing failed: \(error)")
        }
        
        logger.info("📚 Regex total flashcards parsed: \(flashcards.count)")
        return flashcards
    }
    
    // MARK: - Performance Tracking
    
    private func recordPerformanceMetric(_ operation: String, duration: Double, tokenCount: Int = 0) {
        if performanceMetrics[operation] == nil {
            performanceMetrics[operation] = []
        }
        performanceMetrics[operation]?.append(duration)
        
        let tokensPerSecond = tokenCount > 0 ? Double(tokenCount) / duration : 0
        let message = "⚡ \(operation): \(String(format: "%.2f", duration))s" + (tokensPerSecond > 0 ? " (\(String(format: "%.1f", tokensPerSecond)) tok/s)" : "")
        logger.info("\(message)")
    }
} 