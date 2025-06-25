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
        
        let requestId = UUID().uuidString.prefix(8)
        logger.info("🎯 Starting flashcard generation request \(requestId)")
        
        let prompt = buildFlashcardPrompt(text: text)
        logger.info("📝 Request \(requestId) prompt: \(String(prompt.prefix(300)))...")
        
        let startTime = Date()
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 1500)
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("🔍 Request \(requestId) raw flashcard response (\(response.count) chars): \(String(response.prefix(200)))...")
            
            let flashcards = parseFlashcards(from: response)
            
            if flashcards.isEmpty {
                logger.warning("⚠️ Request \(requestId) no flashcards parsed, trying enhanced parsing...")
                let enhancedFlashcards = parseFlashcardsEnhanced(from: response)
                
                if !enhancedFlashcards.isEmpty {
                    recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
                    logger.info("✅ Request \(requestId) generated \(enhancedFlashcards.count) flashcards (enhanced parsing) in \(String(format: "%.2f", duration))s")
                    return enhancedFlashcards
                }
                
                // Try regex-based parsing as final fallback
                logger.warning("⚠️ Request \(requestId) enhanced parsing failed, trying regex parsing...")
                let regexFlashcards = parseFlashcardsWithRegex(from: response)
                
                if !regexFlashcards.isEmpty {
                    recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
                    logger.info("✅ Request \(requestId) generated \(regexFlashcards.count) flashcards (regex parsing) in \(String(format: "%.2f", duration))s")
                    return regexFlashcards
                }
                
                // Try simple text-based parsing as final fallback
                logger.warning("⚠️ Request \(requestId) regex parsing failed, trying simple text parsing...")
                let simpleFlashcards = parseFlashcardsSimple(from: response)
                
                if !simpleFlashcards.isEmpty {
                    recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
                    logger.info("✅ Request \(requestId) generated \(simpleFlashcards.count) flashcards (simple parsing) in \(String(format: "%.2f", duration))s")
                    return simpleFlashcards
                }
                
                logger.error("❌ Request \(requestId) all parsing methods failed. Response was: \(response)")
                throw LLMError.processingFailed("No flashcards could be parsed from response")
            }
            
            recordPerformanceMetric("Flashcard Generation", duration: duration, tokenCount: response.split(separator: " ").count)
            logger.info("✅ Request \(requestId) generated \(flashcards.count) flashcards successfully in \(String(format: "%.2f", duration))s")
            return flashcards
            
        } catch {
            logger.error("❌ Request \(requestId) flashcard generation failed: \(error)")
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
            "context": [], // Reset context to ensure no conversation memory
            "options": [
                "num_predict": maxTokens,
                "temperature": 0.7,
                "top_p": 0.9,
                "repeat_penalty": 1.1,
                "num_ctx": 4096, // Set context window
                "num_thread": 4 // Optimize for performance
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
        <|system|>You are a flashcard creator. This is a new, independent request. Create exactly 3-5 unique flashcards based solely on the provided text. Use ONLY the Q: and A: format. Start each question with "Q:" and each answer with "A:". Do not reference any previous conversations or flashcards. Focus only on the current text provided.<|end|>
        <|user|>Create new flashcards from this text. Use this exact format for each flashcard:

        Q: [Question about the text]
        A: [Answer based on the text]

        Create 3-5 flashcards. Each question should be different and test understanding of key concepts from the text.

        Text: \(truncatedText)<|end|>
        <|assistant|>
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
        
        // Clean the text first
        let cleanedText = cleanGeneratedText(text)
        logger.info("🧹 Cleaned text: \(cleanedText.prefix(300))...")
        
        let lines = cleanedText.components(separatedBy: .newlines)
        var flashcards: [Flashcard] = []
        var currentQuestion = ""
        var currentAnswer = ""
        var collectingAnswer = false
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty { continue }
            
            logger.info("📝 Processing line \(index): '\(trimmedLine)'")
            
            if trimmedLine.hasPrefix("Q:") || trimmedLine.lowercased().hasPrefix("question:") {
                // Save previous flashcard if we have one
                if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
                    flashcards.append(Flashcard(
                        question: currentQuestion,
                        answer: currentAnswer,
                        tags: ["ai-generated", "ollama"]
                    ))
                    logger.info("✅ Parsed flashcard: Q: \(currentQuestion) | A: \(currentAnswer)")
                }
                
                // Extract question
                if trimmedLine.hasPrefix("Q:") {
                    currentQuestion = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if trimmedLine.lowercased().hasPrefix("question:") {
                    currentQuestion = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentAnswer = ""
                collectingAnswer = false
                logger.info("🔍 Found question: '\(currentQuestion)'")
            } else if trimmedLine.hasPrefix("A:") || trimmedLine.lowercased().hasPrefix("answer:") {
                // Extract answer
                if trimmedLine.hasPrefix("A:") {
                    currentAnswer = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if trimmedLine.lowercased().hasPrefix("answer:") {
                    currentAnswer = String(trimmedLine.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                collectingAnswer = true
                logger.info("🔍 Found answer: '\(currentAnswer)'")
            } else if collectingAnswer && !trimmedLine.hasPrefix("Q:") && !trimmedLine.hasPrefix("A:") && !trimmedLine.lowercased().hasPrefix("question:") && !trimmedLine.lowercased().hasPrefix("answer:") {
                // This is a continuation of the answer
                if !currentAnswer.isEmpty {
                    currentAnswer += " " + trimmedLine
                } else {
                    currentAnswer = trimmedLine
                }
                logger.info("🔍 Extended answer: '\(currentAnswer)'")
            } else if !currentQuestion.isEmpty && !collectingAnswer && !trimmedLine.hasPrefix("A:") && !trimmedLine.lowercased().hasPrefix("answer:") {
                // This might be a continuation of the question
                if !trimmedLine.hasPrefix("Q:") && !trimmedLine.lowercased().hasPrefix("question:") {
                    currentQuestion += " " + trimmedLine
                    logger.info("🔍 Extended question: '\(currentQuestion)'")
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
    
    private func parseFlashcardsSimple(from text: String) -> [Flashcard] {
        logger.info("🔍 Simple parsing of response...")
        
        var flashcards: [Flashcard] = []
        let cleanedText = cleanGeneratedText(text)
        
        // Split by potential question/answer separators
        let chunks = cleanedText.components(separatedBy: CharacterSet(charactersIn: "\n\n"))
        
        for chunk in chunks {
            let lines = chunk.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if lines.count >= 2 {
                // Look for any pattern that might be a question/answer pair
                var question = ""
                var answer = ""
                
                for i in 0..<lines.count {
                    let line = lines[i]
                    
                    // If line contains a question mark, treat it as a question
                    if line.contains("?") && question.isEmpty {
                        question = line.replacingOccurrences(of: "^(Q:|Question:|\\d+\\.|\\*\\*Q:|\\*\\*Question:)\\s*", with: "", options: .regularExpression)
                        // Next line might be the answer
                        if i + 1 < lines.count {
                            answer = lines[i + 1].replacingOccurrences(of: "^(A:|Answer:|\\*\\*A:|\\*\\*Answer:)\\s*", with: "", options: .regularExpression)
                        }
                        break
                    }
                }
                
                // If we couldn't find a question with ?, try first two lines
                if question.isEmpty && lines.count >= 2 {
                    question = lines[0].replacingOccurrences(of: "^(Q:|Question:|\\d+\\.|\\*\\*Q:|\\*\\*Question:)\\s*", with: "", options: .regularExpression)
                    answer = lines[1].replacingOccurrences(of: "^(A:|Answer:|\\*\\*A:|\\*\\*Answer:)\\s*", with: "", options: .regularExpression)
                }
                
                if !question.isEmpty && !answer.isEmpty && question.count > 5 && answer.count > 5 {
                    flashcards.append(Flashcard(
                        question: question,
                        answer: answer,
                        tags: ["ai-generated", "ollama", "simple-parsed"]
                    ))
                    logger.info("✅ Simple parsed flashcard: Q: \(question) | A: \(answer)")
                }
            }
        }
        
        logger.info("📚 Simple total flashcards parsed: \(flashcards.count)")
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