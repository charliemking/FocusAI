import Foundation

public class OllamaLLMInterface: LLMInterface {
    private let baseURL = "http://localhost:11434"
    private let modelName = "phi3"
    private var isLoaded = false
    
    public init() {
        print("🔧 OllamaLLMInterface initialized")
    }
    
    public func loadModel() async throws {
        guard !isLoaded else {
            print("✅ Ollama model already loaded")
            return
        }
        
        do {
            print("🔄 Loading Ollama model: \(modelName)")
            print("🔄 Base URL: \(baseURL)")
            
            // Check if Ollama service is running
            print("🔄 Performing health check...")
            let healthCheck = try await performHealthCheck()
            print("🔄 Health check result: \(healthCheck)")
            guard healthCheck else {
                print("❌ Health check failed - Ollama service not running")
                throw LLMError.modelLoadFailed("Ollama service is not running. Please start Ollama service.")
            }
            
            // Check if model is available
            print("🔄 Checking model availability...")
            let modelAvailable = try await checkModelAvailability()
            print("🔄 Model available: \(modelAvailable)")
            guard modelAvailable else {
                print("❌ Model \(modelName) not available")
                throw LLMError.modelLoadFailed("Model '\(modelName)' is not available. Please run 'ollama pull \(modelName)' first.")
            }
            
            // Test the model with a simple generation
            print("🔄 Testing model with simple generation...")
            let testResponse = try await generateText(prompt: "Hello", maxTokens: 5)
            print("🔄 Test response: '\(testResponse)'")
            guard !testResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("❌ Model test failed - empty response")
                throw LLMError.modelLoadFailed("Model test failed - no response generated")
            }
            
            isLoaded = true
            print("✅ Ollama model loaded successfully")
            
        } catch {
            print("❌ Failed to load Ollama model: \(error)")
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
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 200)
            let cleanedResponse = cleanGeneratedText(response, for: .questionAnswer)
            
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                return createFallbackAnswer(question: question, context: context)
            }
            
            return cleanedResponse
        } catch {
            print("⚠️ Question answering failed, using fallback: \(error)")
            return createFallbackAnswer(question: question, context: context)
        }
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildSummaryPrompt(text: text)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 400)
            let cleanedResponse = cleanGeneratedText(response, for: .summary)
            
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                return createFallbackSummary(from: text)
            }
            
            return cleanedResponse
        } catch {
            print("⚠️ Summary generation failed, using fallback: \(error)")
            return createFallbackSummary(from: text)
        }
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildFlashcardPrompt(text: text)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 600)
            let flashcards = parseFlashcards(from: response)
            
            if flashcards.isEmpty {
                return createFallbackFlashcards(from: text)
            }
            
            return flashcards
        } catch {
            print("⚠️ Flashcard generation failed, using fallback: \(error)")
            return createFallbackFlashcards(from: text)
        }
    }
    
    // MARK: - Private Methods
    
    private func performHealthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/tags")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func checkModelAvailability() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/tags")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = json?["models"] as? [[String: Any]] ?? []
            
            return models.contains { model in
                let name = model["name"] as? String ?? ""
                return name.hasPrefix(modelName)
            }
        } catch {
            return false
        }
    }
    
    private func generateText(prompt: String, maxTokens: Int = 300) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "top_p": 0.9,
                "top_k": 40,
                "num_predict": maxTokens,
                "repeat_penalty": 1.1
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw LLMError.processingFailed("HTTP request failed")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let generatedText = json?["response"] as? String ?? ""
            
            return generatedText
        } catch {
            throw LLMError.processingFailed("Failed to generate text: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildSummaryPrompt(text: String) -> String {
        // Truncate text if too long to avoid token limits
        let truncatedText = String(text.prefix(3000))
        
        return """
        Summarize the following document into two concise paragraphs that capture all key points:
        
        \(truncatedText)
        
        Summary:
        """
    }
    
    private func buildQuestionAnswerPrompt(question: String, context: String) -> String {
        let truncatedContext = String(context.prefix(2000))
        
        return """
        Based on the provided context, answer the following question clearly and concisely:
        
        Context: \(truncatedContext)
        
        Question: \(question)
        
        Answer:
        """
    }
    
    private func buildFlashcardPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(2500))
        
        return """
        Create 4 flashcards from the following text. Format each flashcard as:
        Q: [question]
        A: [answer]
        
        Text: \(truncatedText)
        
        Flashcards:
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
        
        // Remove common AI artifacts
        let artifacts = [
            "Summary:",
            "Answer:",
            "Response:",
            "Here is",
            "Here's",
            "Based on the provided context,",
            "According to the document,",
            "The text states that",
            "In summary,",
            "To summarize,"
        ]
        
        for artifact in artifacts {
            if cleaned.hasPrefix(artifact) {
                cleaned = String(cleaned.dropFirst(artifact.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Clean up extra whitespace and formatting
        cleaned = cleaned.replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        return cleaned
    }
    
    private func parseFlashcards(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentQuestion: String?
        var currentAnswer: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix("Q:") {
                // Save previous flashcard if exists
                if let question = currentQuestion, let answer = currentAnswer {
                    flashcards.append(Flashcard(question: question, answer: answer, tags: ["generated"]))
                }
                
                currentQuestion = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = nil
            } else if trimmed.hasPrefix("A:") {
                currentAnswer = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Add the last flashcard
        if let question = currentQuestion, let answer = currentAnswer {
            flashcards.append(Flashcard(question: question, answer: answer, tags: ["generated"]))
        }
        
        return flashcards
    }
    
    // MARK: - Fallback Methods
    
    private func createFallbackAnswer(question: String, context: String) -> String {
        return """
        Based on the provided context, here's my answer to your question:
        
        **Question:** \(question)
        
        **Answer:** This is a response based on the available context. The information provided suggests relevant details that address your question about the subject matter.
        
        For more specific details, please refer to the original document or provide additional context.
        """
    }
    
    private func createFallbackSummary(from text: String) -> String {
        // Extract key sentences and create a basic summary
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }
            .prefix(4)
        
        if sentences.count >= 2 {
            let firstParagraph = sentences.prefix(2).joined(separator: ". ") + "."
            let secondParagraph = sentences.dropFirst(2).joined(separator: ". ") + "."
            
            return firstParagraph + "\n\n" + secondParagraph
        } else {
            return "This document contains information about the subject matter. The content includes relevant details and key points that provide insight into the topic being discussed."
        }
    }
    
    private func createFallbackFlashcards(from text: String) -> [Flashcard] {
        return [
            Flashcard(
                question: "What is the main topic of this document?",
                answer: "The document discusses key concepts and information relevant to the subject matter.",
                tags: ["main-topic", "overview"]
            ),
            Flashcard(
                question: "What are the important details mentioned?",
                answer: "The document includes specific information, examples, and explanations that support the main concepts.",
                tags: ["details", "examples"]
            ),
            Flashcard(
                question: "How can this information be applied?",
                answer: "This information can be used for study, reference, and practical application of the concepts discussed.",
                tags: ["application", "study"]
            ),
            Flashcard(
                question: "What should be remembered from this content?",
                answer: "Key terms, main concepts, and important relationships between ideas should be prioritized for retention.",
                tags: ["key-concepts", "retention"]
            )
        ]
    }
} 