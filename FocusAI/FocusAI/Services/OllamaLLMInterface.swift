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
            logger.info("🔍 Sending prompt to Ollama: \(String(prompt.prefix(300)))...")
            let response = try await generateText(prompt: prompt, maxTokens: 500)
            let duration = Date().timeIntervalSince(startTime)
            logger.info("🔍 Raw Ollama response length: \(response.count) characters")
            logger.info("🔍 Raw Ollama response: \(String(response.prefix(300)))...")
            let cleanedResponse = cleanGeneratedText(response)
            logger.info("🔍 Cleaned response length: \(cleanedResponse.count) characters")
            logger.info("🔍 Cleaned response: \(String(cleanedResponse.prefix(300)))...")
            
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
    
    public func generateFlashcards(text: String, count: Int = 5) async throws -> [Flashcard] {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let requestId = UUID().uuidString.prefix(8)
        logger.info("🎯 Starting flashcard generation request \(requestId)")
        
        let prompt = buildFlashcardPrompt(text: text, count: count)
        logger.info("📝 Request \(requestId) prompt: \(String(prompt.prefix(300)))...")
        
        let startTime = Date()
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 3000)
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("🔍 Request \(requestId) raw flashcard response (\(response.count) chars): \(String(response.prefix(200)))...")
            
            let flashcards = parseFlashcardsEmergency(from: response)
            
            if flashcards.isEmpty {
                logger.error("❌ Request \(requestId) no flashcards parsed from response: \(response)")
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
        logger.info("🔍 Ollama response length: \(ollamaResponse.response.count) chars, done: \(ollamaResponse.done)")
        logger.info("🔍 Raw Ollama response: \(ollamaResponse.response)")
        return ollamaResponse.response
    }
    
    // MARK: - Prompt Building
    
    private func buildQuestionAnswerPrompt(question: String, context: String) -> String {
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContext.isEmpty {
            // For general questions without context - use simple format that works with phi3:mini
            return """
            Question: \(question)

            Answer:
            """
        } else {
            // For questions with context - use simple format
            let truncatedContext = String(trimmedContext.prefix(6000))
            return """
            Context: \(truncatedContext)

            Question: \(question)

            Answer:
            """
        }
    }
    
    private func buildSummaryPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(3000))
        
        return """
        <|system|>You are a helpful AI assistant that creates concise, informative summaries. Focus on key points and main ideas.<|end|>
        <|user|>Please summarize this text in exactly 5 sentences. Cover the main points and key ideas in a comprehensive but concise way. Do not number the sentences or use any numbering format. Write the summary as a natural paragraph:

        \(truncatedText)<|end|>
        <|assistant|>Here's a 5-sentence summary of the text:

        """
    }
    
    private func buildFlashcardPrompt(text: String, count: Int) -> String {
        let truncatedText = String(text.prefix(3000))
        
        return """
        <|system|>You are a flashcard creator. You MUST create exactly \(count) unique flashcards based solely on the provided text. Use ONLY the Q: and A: format. Start each question with "Q:" and each answer with "A:". Do not use any headers, numbering, or formatting like "**flashcard 2**" or "Card 1:". Use only the simple Q: and A: format. 

        CRITICAL: You must generate exactly \(count) flashcards - no more, no less. Count them as you create them.

        IMPORTANT: Keep answers BRIEF and CONCISE. Each answer should be 1-2 sentences maximum or under 40 words. Focus on the most essential information only.<|end|>
        <|user|>Create new flashcards from this text. Use this exact format for each flashcard:

        Q: [Brief question about the text]
        A: [Brief, concise answer - 1-2 sentences max]

        Examples of good short answers:
        Q: What is artificial intelligence?
        A: AI refers to machines that can perform tasks requiring human intelligence.

        Q: What are the main benefits of renewable energy?
        A: Clean energy, reduced emissions, and long-term cost savings.

        You MUST create exactly \(count) flashcards. Each question should be different and test understanding of key concepts from the text.

        CRITICAL REQUIREMENTS: 
        - Generate exactly \(count) flashcards - count them as you create them
        - Do not use any headers, numbering, or formatting like "**flashcard 2**", "Card 1:", or "Flashcard 1:"
        - Keep answers brief and concise (1-2 sentences or under 40 words)
        - Focus on essential information only
        - Use only the simple Q: and A: format shown above
        - Generate enough diverse questions to reach exactly \(count) flashcards

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
                        question: cleanFlashcardText(currentQuestion),
                        answer: truncateAnswerIfNeeded(cleanFlashcardText(currentAnswer)),
                        tags: ["ai-generated", "ollama"]
                    ))
                    logger.info("✅ Parsed flashcard: Q: \(self.cleanFlashcardText(currentQuestion)) | A: \(self.truncateAnswerIfNeeded(self.cleanFlashcardText(currentAnswer)))")
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
                question: cleanFlashcardText(currentQuestion),
                answer: truncateAnswerIfNeeded(cleanFlashcardText(currentAnswer)),
                tags: ["ai-generated", "ollama"]
            ))
            logger.info("✅ Parsed final flashcard: Q: \(self.cleanFlashcardText(currentQuestion)) | A: \(self.truncateAnswerIfNeeded(self.cleanFlashcardText(currentAnswer)))")
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
                        question: cleanFlashcardText(currentQuestion),
                        answer: truncateAnswerIfNeeded(cleanFlashcardText(currentAnswer)),
                        tags: ["ai-generated", "ollama"]
                    ))
                    logger.info("✅ Enhanced parsed flashcard: Q: \(self.cleanFlashcardText(currentQuestion)) | A: \(self.truncateAnswerIfNeeded(self.cleanFlashcardText(currentAnswer)))")
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
                question: cleanFlashcardText(currentQuestion),
                answer: truncateAnswerIfNeeded(cleanFlashcardText(currentAnswer)),
                tags: ["ai-generated", "ollama"]
            ))
            logger.info("✅ Enhanced parsed final flashcard: Q: \(self.cleanFlashcardText(currentQuestion)) | A: \(self.truncateAnswerIfNeeded(self.cleanFlashcardText(currentAnswer)))")
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
                        let question = cleanFlashcardText(String(text[questionRange]))
                        let answer = cleanFlashcardText(String(text[answerRange]))
                        
                        if !question.isEmpty && !answer.isEmpty {
                            flashcards.append(Flashcard(
                                question: question,
                                answer: truncateAnswerIfNeeded(answer),
                                tags: ["ai-generated", "ollama", "regex-parsed"]
                            ))
                            logger.info("✅ Regex parsed flashcard: Q: \(question) | A: \(self.truncateAnswerIfNeeded(answer))")
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
                        question = cleanFlashcardText(line)
                        // Next line might be the answer
                        if i + 1 < lines.count {
                            answer = cleanFlashcardText(lines[i + 1])
                        }
                        break
                    }
                }
                
                // If we couldn't find a question with ?, try first two lines
                if question.isEmpty && lines.count >= 2 {
                    question = cleanFlashcardText(lines[0])
                    answer = cleanFlashcardText(lines[1])
                }
                
                if !question.isEmpty && !answer.isEmpty && question.count > 5 && answer.count > 5 {
                    flashcards.append(Flashcard(
                        question: question,
                        answer: truncateAnswerIfNeeded(answer),
                        tags: ["ai-generated", "ollama", "simple-parsed"]
                    ))
                    logger.info("✅ Simple parsed flashcard: Q: \(question) | A: \(self.truncateAnswerIfNeeded(answer))")
                }
            }
        }
        
        logger.info("📚 Simple total flashcards parsed: \(flashcards.count)")
        return flashcards
    }
    
    private func parseFlashcardsFromText(from text: String) -> [Flashcard] {
        logger.info("🔍 Text-based parsing of response...")
        logger.info("📝 Raw text: \(text)")
        
        var flashcards: [Flashcard] = []
        
        // First try: Split text into lines and look for Q: and A: patterns
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        logger.info("📊 Processing \(lines.count) lines")
        
        var currentQuestion = ""
        var currentAnswer = ""
        
        for line in lines {
            logger.info("🔍 Processing line: \(line)")
            
            if line.hasPrefix("Q:") {
                // Save previous flashcard if we have one
                if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
                    let question = cleanFlashcardText(currentQuestion)
                    let answer = cleanFlashcardText(currentAnswer)
                    
                    flashcards.append(Flashcard(
                        question: question,
                        answer: truncateAnswerIfNeeded(answer),
                        tags: ["ai-generated", "ollama", "text-parsed"]
                    ))
                    logger.info("✅ Saved flashcard: Q: \(question) | A: \(answer)")
                }
                
                // Start new question
                currentQuestion = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = ""
                logger.info("📝 New question: \(currentQuestion)")
                
            } else if line.hasPrefix("A:") {
                currentAnswer = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.info("📝 Answer: \(currentAnswer)")
                
            } else if !currentAnswer.isEmpty {
                // This might be a continuation of the answer
                currentAnswer += " " + line
                logger.info("📝 Extended answer: \(currentAnswer)")
            } else if !currentQuestion.isEmpty {
                // This might be a continuation of the question
                currentQuestion += " " + line
                logger.info("📝 Extended question: \(currentQuestion)")
            }
        }
        
        // Don't forget the last flashcard
        if !currentQuestion.isEmpty && !currentAnswer.isEmpty {
            let question = cleanFlashcardText(currentQuestion)
            let answer = cleanFlashcardText(currentAnswer)
            
            flashcards.append(Flashcard(
                question: question,
                answer: truncateAnswerIfNeeded(answer),
                tags: ["ai-generated", "ollama", "text-parsed"]
            ))
            logger.info("✅ Final flashcard: Q: \(question) | A: \(answer)")
        }
        
        logger.info("📚 Text parsing found \(flashcards.count) flashcards")
        return flashcards
    }
    
    private func parseFlashcardsEmergency(from text: String) -> [Flashcard] {
        logger.info("🔄 Emergency parsing - extracting Q&A from raw response")
        var flashcards: [Flashcard] = []
        
        // Split the response and look for any Q:/A: patterns
        let sections = text.components(separatedBy: CharacterSet.newlines)
        var currentQ = ""
        var currentA = ""
        
        for line in sections {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.starts(with: "Q:") || trimmed.range(of: "^Q\\d+:", options: .regularExpression) != nil {
                // Save previous pair if exists
                if !currentQ.isEmpty && !currentA.isEmpty {
                    flashcards.append(Flashcard(
                        question: cleanFlashcardText(currentQ),
                        answer: cleanFlashcardText(currentA),
                        tags: ["ai-generated", "ollama"]
                    ))
                }
                // Extract question text after the colon
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    currentQ = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentA = ""
            } else if trimmed.starts(with: "A:") || trimmed.range(of: "^A\\d+:", options: .regularExpression) != nil {
                // Extract answer text after the colon
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    currentA = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if !currentA.isEmpty {
                // Continuation of answer
                currentA += " " + trimmed
            } else if !currentQ.isEmpty {
                // Continuation of question
                currentQ += " " + trimmed
            }
        }
        
        // Don't forget the last pair
        if !currentQ.isEmpty && !currentA.isEmpty {
            flashcards.append(Flashcard(
                question: cleanFlashcardText(currentQ),
                answer: cleanFlashcardText(currentA),
                tags: ["ai-generated", "ollama"]
            ))
        }
        
        logger.info("📚 Emergency parsing found \(flashcards.count) flashcards")
        return flashcards
    }
    
    // MARK: - Text Cleaning Helper
    
    private func cleanFlashcardText(_ text: String) -> String {
        var cleaned = text
        
        // Remove common flashcard prefixes and headers
        let patternsToRemove = [
            "^(Q:|Question:|\\d+\\.|\\*\\*Q:|\\*\\*Question:)\\s*",
            "^(A:|Answer:|\\*\\*A:|\\*\\*Answer:)\\s*",
            "^\\*\\*[Ff]lashcard\\s*\\d+\\*\\*\\s*",
            "^\\*\\*[Ff]lashcard\\s*\\d+:\\*\\*\\s*",
            "^[Ff]lashcard\\s*\\d+:\\s*",
            "^[Ff]lashcard\\s*\\d+\\s*",
            "^\\*\\*[Cc]ard\\s*\\d+\\*\\*\\s*",
            "^[Cc]ard\\s*\\d+:\\s*"
        ]
        
        for pattern in patternsToRemove {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Answer Length Management
    
    private func truncateAnswerIfNeeded(_ answer: String, maxWords: Int = 40) -> String {
        let words = answer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if words.count <= maxWords {
            return answer
        }
        
        // Take first maxWords and try to end at a sentence boundary
        let truncatedWords = Array(words.prefix(maxWords))
        let truncatedText = truncatedWords.joined(separator: " ")
        
        // If it ends with a period, return as is
        if truncatedText.hasSuffix(".") {
            return truncatedText
        }
        
        // Otherwise, try to find the last sentence boundary
        if let lastPeriodIndex = truncatedText.lastIndex(of: ".") {
            let endIndex = truncatedText.index(after: lastPeriodIndex)
            return String(truncatedText[..<endIndex])
        }
        
        // If no sentence boundary, add ellipsis
        return truncatedText + "..."
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