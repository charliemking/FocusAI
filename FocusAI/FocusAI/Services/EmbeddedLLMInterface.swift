import Foundation
import OSLog

public class EmbeddedLLMInterface: LLMInterface {
    private let logger = Logger(subsystem: "com.focusai.app", category: "EmbeddedLLM")
    
    // Server configuration
    private let serverPort: Int = 8080
    private var serverProcess: Process?
    private var isLoaded = false
    private var baseURL: String { "http://127.0.0.1:\(self.serverPort)" }
    
    // File paths
    private var llamaCppServerPath: String {
        guard let bundlePath = Bundle.main.path(forResource: "llama-server", ofType: "") else {
            fatalError("llama-server binary not found in app bundle")
        }
        return bundlePath
    }
    
    private var modelPath: String {
        guard let modelPath = Bundle.main.path(forResource: "phi-3-mini-4k-instruct", ofType: "gguf") else {
            fatalError("Phi-3 model not found in app bundle")
        }
        return modelPath
    }
    
    public init() {
        logger.info("🔧 EmbeddedLLMInterface initialized")
    }
    
    deinit {
        stopServer()
    }
    
    // MARK: - LLMInterface Implementation
    
    public func loadModel() async throws {
        guard !isLoaded else {
            logger.info("✅ Embedded model already loaded")
            return
        }
        
        do {
            logger.info("🔄 Starting embedded llama.cpp server")
            try await startServer()
            
            logger.info("🔄 Waiting for server to be ready...")
            try await waitForServerReady()
            
            logger.info("🔄 Testing model with simple generation...")
            let testPrompt = "<|system|>You are a helpful AI assistant.<|end|>\n<|user|>Hello! Please respond with a brief greeting.<|end|>\n<|assistant|>"
            let testResponse = try await generateText(prompt: testPrompt, maxTokens: 20)
            guard !testResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.modelLoadFailed("Model test failed - no response generated")
            }
            logger.info("✅ Test response: \(testResponse.prefix(50))...")
            
            isLoaded = true
            logger.info("✅ Embedded Phi-3 model loaded successfully")
            
        } catch {
            logger.error("❌ Failed to load embedded model: \(error.localizedDescription)")
            stopServer()
            throw LLMError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    public func isModelLoaded() -> Bool {
        return isLoaded && serverProcess?.isRunning == true
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildQuestionAnswerPrompt(question: question, context: context)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 500)
            let cleanedResponse = cleanGeneratedText(response, for: .questionAnswer)
            
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                return createFallbackAnswer(question: question, context: context)
            }
            
            return cleanedResponse
        } catch {
            logger.warning("⚠️ Question answering failed, using fallback: \(error.localizedDescription)")
            return createFallbackAnswer(question: question, context: context)
        }
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildSummaryPrompt(text: text)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 800)
            let cleanedResponse = cleanGeneratedText(response, for: .summary)
            
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                return createFallbackSummary(from: text)
            }
            
            return cleanedResponse
        } catch {
            logger.warning("⚠️ Summary generation failed, using fallback: \(error.localizedDescription)")
            return createFallbackSummary(from: text)
        }
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildFlashcardPrompt(text: text)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 1000)
            let flashcards = parseFlashcards(from: response)
            
            if flashcards.isEmpty {
                return createFallbackFlashcards(from: text)
            }
            
            return flashcards
        } catch {
            logger.warning("⚠️ Flashcard generation failed, using fallback: \(error.localizedDescription)")
            return createFallbackFlashcards(from: text)
        }
    }
    
    // MARK: - Server Management
    
    private func startServer() async throws {
        // Ensure any existing server is stopped
        stopServer()
        
        // Log file paths for debugging
        logger.info("🔍 Server executable path: \(self.llamaCppServerPath)")
        logger.info("🔍 Model path: \(self.modelPath)")
        
        // Verify files exist
        guard FileManager.default.fileExists(atPath: llamaCppServerPath) else {
            throw LLMError.modelLoadFailed("Server executable not found at: \(llamaCppServerPath)")
        }
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LLMError.modelLoadFailed("Model file not found at: \(modelPath)")
        }
        
        // Create the server process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: llamaCppServerPath)
        
        // Configure server arguments for optimal performance
        process.arguments = [
            "--model", modelPath,
            "--port", "\(self.serverPort)",
            "--host", "127.0.0.1",
            "--ctx-size", "4096", // Reduced back to 4096 for faster loading
            "--threads", "\(max(1, ProcessInfo.processInfo.processorCount - 1))",
            "--n-gpu-layers", "0", // Disable GPU for stability
            "--log-disable", // Disable detailed logging for production
        ]
        
        logger.info("🔍 Server arguments: \(process.arguments ?? [])")
        
        // Create pipes for capturing output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment variables and library search path
        var environment = ProcessInfo.processInfo.environment
        // Metal GPU acceleration is now enabled for better performance
        
        // Add library search path for bundled dylibs
        if let resourcePath = Bundle.main.resourcePath {
            if let existingDyldPath = environment["DYLD_LIBRARY_PATH"] {
                environment["DYLD_LIBRARY_PATH"] = "\(resourcePath):\(existingDyldPath)"
            } else {
                environment["DYLD_LIBRARY_PATH"] = resourcePath
            }
            logger.info("🔍 Library search path: \(resourcePath)")
        }
        
        process.environment = environment
        
        logger.info("🔍 Starting process...")
        
        do {
            try process.run()
            serverProcess = process
            
            logger.info("🚀 llama.cpp server started on port \(self.serverPort)")
            
            // Check if process is still running after a short delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if !process.isRunning {
                // Capture any error output
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "No error output"
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let standardOutput = String(data: outputData, encoding: .utf8) ?? "No standard output"
                
                logger.error("❌ Server process terminated immediately")
                logger.error("❌ Error output: \(errorOutput)")
                logger.error("❌ Standard output: \(standardOutput)")
                
                throw LLMError.modelLoadFailed("Server failed to start within timeout period")
            }
            
        } catch {
            logger.error("❌ Failed to start server process: \(error)")
            throw LLMError.modelLoadFailed("Failed to start server: \(error.localizedDescription)")
        }
    }
    
    private func stopServer() {
        guard let process = serverProcess, process.isRunning else { return }
        
        logger.info("🛑 Stopping llama.cpp server")
        process.terminate()
        
        // Wait for graceful termination
        let deadline = Date().addingTimeInterval(5.0)
        while process.isRunning && Date() < deadline {
            usleep(100_000) // 0.1 seconds
        }
        
        // Force kill if still running
        if process.isRunning {
            logger.warning("⚠️ Force killing llama.cpp server")
            kill(process.processIdentifier, SIGKILL)
        }
        
        serverProcess = nil
        isLoaded = false
    }
    
    private func waitForServerReady() async throws {
        let maxAttempts = 60 // Increased from 30 to 60 (2 minutes)
        var attempts = 0
        
        while attempts < maxAttempts {
            do {
                let url = URL(string: "http://127.0.0.1:\(serverPort)/health")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 10 // Increased timeout per request
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    logger.info("Server is ready after \(attempts + 1) attempts")
                    return
                }
            } catch {
                // Continue trying
            }
            
            attempts += 1
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds between attempts
        }
        
        throw LLMError.modelLoadFailed("Server failed to start within timeout period")
    }
    
    // MARK: - Text Generation
    
    private func generateText(prompt: String, maxTokens: Int = 300) async throws -> String {
        let url = URL(string: "\(baseURL)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Increased from 60 to 120 seconds
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "n_predict": maxTokens,
            "temperature": 0.7,
            "top_p": 0.9,
            "top_k": 40,
            "repeat_penalty": 1.1,
            "stream": false,
            "stop": ["<|end|>", "<|user|>"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.processingFailed("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw LLMError.processingFailed("HTTP \(httpResponse.statusCode)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let generatedText = json?["content"] as? String ?? ""
            
            return generatedText
        } catch {
            throw LLMError.processingFailed("Failed to generate text: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildSummaryPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(12000)) // Reduced from 15000 for faster processing
        return """
        <|system|>You are an expert summarization assistant. Create comprehensive, well-structured summaries that capture the main ideas, key arguments, supporting details, and conclusions. Write in clear, engaging prose that maintains the original meaning while being concise.<|end|>
        <|user|>Please analyze the following text and create a detailed summary. Structure your response with clear paragraphs covering:
        1. Main topic and purpose
        2. Key points and arguments
        3. Important details and examples
        4. Conclusions or implications

        Text to summarize:
        \(truncatedText)

        Please provide a comprehensive summary:<|end|>
        <|assistant|>
        """
    }
    
    private func buildQuestionAnswerPrompt(question: String, context: String) -> String {
        let truncatedContext = String(context.prefix(10000)) // Reduced from 12000 for faster processing
        return """
        <|system|>You are a knowledgeable research assistant that provides thorough, accurate answers based on the given context. Analyze the context carefully and provide detailed, well-reasoned responses. Use specific information from the context to support your answers.<|end|>
        <|user|>Context for reference:
        \(truncatedContext)

        Question: \(question)

        Please provide a comprehensive answer based on the context above. Include specific details and explain your reasoning.<|end|>
        <|assistant|>
        """
    }
    
    private func buildFlashcardPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(10000))
        return """
        <|system|>You are an expert educational content creator. Create high-quality flashcards that test key concepts, important facts, and critical understanding. Each flashcard should have a clear, specific question and a comprehensive but concise answer. Focus on the most important information that students need to learn.<|end|>
        <|user|>Create 5-8 educational flashcards from the following content. Focus on the most important concepts, facts, and ideas that students should remember. Format each flashcard exactly as:

        Q: [Clear, specific question]
        A: [Comprehensive but concise answer]

        Content:
        \(truncatedText)<|end|>
        <|assistant|>
        """
    }
    
    // MARK: - Response Processing
    
    private enum GenerationType {
        case summary
        case questionAnswer
        case flashcard
    }
    
    private func cleanGeneratedText(_ text: String, for type: GenerationType) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common AI prefixes
        let prefixesToRemove = [
            "Here's a summary:",
            "Summary:",
            "Here is a summary:",
            "Here is an example summary:",
            "Based on the provided context:",
            "Answer:",
            "Here's the answer:",
        ]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        

        return cleaned
    }
    
    private func parseFlashcards(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentQuestion: String?
        var currentAnswer: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.lowercased().hasPrefix("q:") || trimmed.lowercased().hasPrefix("question:") {
                // Save previous flashcard if complete
                if let q = currentQuestion, let a = currentAnswer {
                    flashcards.append(Flashcard(question: q, answer: a))
                }
                
                currentQuestion = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = nil
            } else if trimmed.lowercased().hasPrefix("a:") || trimmed.lowercased().hasPrefix("answer:") {
                currentAnswer = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Add the last flashcard
        if let q = currentQuestion, let a = currentAnswer {
            flashcards.append(Flashcard(question: q, answer: a))
        }
        
        return flashcards
    }
    
    // MARK: - Fallback Methods
    
    private func createFallbackAnswer(question: String, context: String) -> String {
        return """
        Based on the provided context, here's what I can tell you about your question:
        
        **Question:** \(question)
        
        **Answer:** The context discusses relevant information that helps address your question. While I cannot provide a complete AI-generated response at this moment, I encourage you to review the key sections of the material that relate to: \(extractKeyTerms(from: context).prefix(3).joined(separator: ", ")).
        
        For the most accurate information, please refer to the original source material.
        """
    }
    
    private func createFallbackSummary(from text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }
            .prefix(3)
        
        if sentences.isEmpty {
            return "Summary: The provided text contains information about \(extractKeyTerms(from: text).prefix(3).joined(separator: ", ")). Please review the original content for detailed information."
        }
        
        return sentences.joined(separator: ". ") + "."
    }
    
    private func createFallbackFlashcards(from text: String) -> [Flashcard] {
        let keyTerms = extractKeyTerms(from: text).prefix(6)
        return keyTerms.map { term in
            Flashcard(
                question: "What is \(term)?",
                answer: "Based on the provided text, \(term) is an important concept. Please review the source material for detailed information."
            )
        }
    }
    
    private func extractKeyTerms(from text: String) -> [String] {
        let commonWords = Set([
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "a", "an", "is", "are", "was", "were", "be", "been", "have", "has", "had"
        ])
        
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in
                word.count >= 4 &&
                word.count <= 20 &&
                !commonWords.contains(word) &&
                !word.allSatisfy { $0.isNumber }
            }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        return Array(wordCounts)
    }
} 
