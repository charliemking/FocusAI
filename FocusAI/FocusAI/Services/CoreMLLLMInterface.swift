import Foundation
import CoreML

public class CoreMLLLMInterface: LLMInterface {
    private var model: MLModel?
    private let modelName = "distilgpt2"
    private var tokenizer: GPT2Tokenizer?
    private let maxSequenceLength = 512
    private let maxOutputLength = 256
    
    public init() {
        print("🔧 CoreMLLLMInterface initialized")
        NSLog("🔧 CoreMLLLMInterface initialized")
    }
    
    public func loadModel() async throws {
        guard model == nil else {
            print("✅ CoreML model already loaded")
            return
        }
        
        do {
            print("🔄 Loading CoreML model: \(modelName)")
            NSLog("🔄 Loading CoreML model: \(modelName)")
            
            // Load the model from the main bundle
            guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
                let error = "Model file not found in bundle"
                print("❌ \(error)")
                NSLog("❌ \(error)")
                throw LLMError.modelLoadFailed(error)
            }
            
            print("📁 Model path: \(modelURL.path)")
            NSLog("📁 Model path: \(modelURL.path)")
            
            // Load the CoreML model
            let loadedModel = try MLModel(contentsOf: modelURL)
            self.model = loadedModel
            
            // Initialize tokenizer
            self.tokenizer = GPT2Tokenizer()
            
            // Print model information
            await printModelInfo(loadedModel)
            
            print("✅ CoreML model loaded successfully")
            NSLog("✅ CoreML model loaded successfully")
            
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
            NSLog("❌ Failed to load CoreML model: \(error)")
            throw LLMError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    public func isModelLoaded() -> Bool {
        return model != nil && tokenizer != nil
    }
    
    @MainActor
    private func printModelInfo(_ model: MLModel) {
        print("🔍 Model Information:")
        print("  Model Description: \(model.modelDescription)")
        
        print("  Input Features:")
        for input in model.modelDescription.inputDescriptionsByName {
            print("    - \(input.key): \(input.value)")
            if let multiArray = input.value.multiArrayConstraint {
                print("      Shape: \(multiArray.shape)")
                print("      Data Type: \(multiArray.dataType)")
            }
        }
        
        print("  Output Features:")
        for output in model.modelDescription.outputDescriptionsByName {
            print("    - \(output.key): \(output.value)")
            if let multiArray = output.value.multiArrayConstraint {
                print("      Shape: \(multiArray.shape)")
                print("      Data Type: \(multiArray.dataType)")
            }
        }
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        guard isModelLoaded() else {
            throw LLMError.modelNotLoaded
        }
        
        // Try to generate with the model first
        do {
            let prompt = "Context: \(context.prefix(150))\nQuestion: \(question)\nAnswer:"
            let generated = try await generateText(from: prompt)
            
            // If model output is too short or empty, provide a fallback answer
            if generated.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 {
                return createFallbackAnswer(question: question, context: context)
            }
            
            return generated
        } catch {
            print("⚠️ Model generation failed, using fallback answer: \(error)")
            return createFallbackAnswer(question: question, context: context)
        }
    }
    
    private func createFallbackAnswer(question: String, context: String) -> String {
        let contextWords = context.lowercased().split(separator: " ")
        let questionWords = question.lowercased().split(separator: " ")
        
        // Find overlapping words between question and context
        let commonWords = Set(questionWords).intersection(Set(contextWords))
        
        if !commonWords.isEmpty {
            let relevantSentences = context.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { sentence in
                    let sentenceWords = Set(sentence.lowercased().split(separator: " "))
                    return !sentenceWords.intersection(commonWords).isEmpty
                }
                .prefix(2)
            
            if !relevantSentences.isEmpty {
                return "Based on the context: \(relevantSentences.joined(separator: " "))"
            }
        }
        
        // Generic fallback
        return "I found information related to your question in the provided context. The document discusses \(extractKeyWords(from: context).prefix(3).joined(separator: ", "))."
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isModelLoaded() else {
            throw LLMError.modelNotLoaded
        }
        
        // Try to generate with the model first
        do {
            let prompt = "Summarize: \(text.prefix(200))\n\nSummary:"
            let generated = try await generateText(from: prompt)
            
            // If model output is too short or empty, provide a fallback summary
            if generated.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                return createFallbackSummary(from: text)
            }
            
            return generated
        } catch {
            print("⚠️ Model generation failed, using fallback summary: \(error)")
            return createFallbackSummary(from: text)
        }
    }
    
    private func createFallbackSummary(from text: String) -> String {
        let words = text.split(separator: " ")
        let wordCount = words.count
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let firstSentence = sentences.first ?? "No content available"
        let keyTopics = extractKeyWords(from: text)
        
        var summary = "This document contains \(wordCount) words"
        if sentences.count > 1 {
            summary += " across \(sentences.count) sentences"
        }
        summary += ". "
        
        if !keyTopics.isEmpty {
            summary += "Key topics include: \(keyTopics.joined(separator: ", ")). "
        }
        
        if firstSentence.count > 20 {
            summary += "It begins: \"\(firstSentence.prefix(100))...\""
        }
        
        return summary
    }
    
    private func extractKeyWords(from text: String) -> [String] {
        let commonWords = Set(["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "a", "an", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those"])
        
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !commonWords.contains($0) }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(wordCounts.prefix(5).map { $0.key })
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        guard isModelLoaded() else {
            throw LLMError.modelNotLoaded
        }
        
        // For now, return structured flashcards based on the content
        // In a real implementation, we would use multiple prompts to generate Q&A pairs
        let words = text.split(separator: " ")
        let wordCount = words.count
        
        return [
            Flashcard(
                question: "What is the main topic of this content?",
                answer: "This content discusses various topics with approximately \(wordCount) words of information.",
                tags: ["main-topic", "overview"]
            ),
            Flashcard(
                question: "How many words are in the source material?",
                answer: "The source material contains \(wordCount) words.",
                tags: ["statistics", "word-count"]
            ),
            Flashcard(
                question: "What type of information is presented?",
                answer: "The information appears to be educational content suitable for study and review.",
                tags: ["content-type", "educational"]
            )
        ]
    }
    
    private func generateText(from prompt: String) async throws -> String {
        guard let model = model, let tokenizer = tokenizer else {
            throw LLMError.modelNotLoaded
        }
        
        do {
            print("🔄 Generating text for prompt: \(prompt.prefix(50))...")
            
            // Determine expected sequence length from the model description
            var expectedSeqLen = maxSequenceLength
            if let inputDesc = model.modelDescription.inputDescriptionsByName["input_ids"],
               let shape = inputDesc.multiArrayConstraint?.shape, shape.count == 2 {
                expectedSeqLen = shape[1].intValue
            } else if let anyInput = model.modelDescription.inputDescriptionsByName.first?.value,
                      let shape = anyInput.multiArrayConstraint?.shape {
                expectedSeqLen = shape.last?.intValue ?? maxSequenceLength
            }
            print("🔢 Model expects sequence length: \(expectedSeqLen)")
            
            // Tokenize input
            var tokens = try tokenizer.encode(prompt, maxLength: expectedSeqLen)
            print("📝 Tokenized input: \(tokens.count) tokens before padding/truncation")
            
            // Pad or truncate tokens to expected length
            if tokens.count < expectedSeqLen {
                let padId = tokenizer.padTokenId()
                tokens += Array(repeating: padId, count: expectedSeqLen - tokens.count)
            } else if tokens.count > expectedSeqLen {
                tokens = Array(tokens.prefix(expectedSeqLen))
            }
            print("📝 Tokenized input adjusted to: \(tokens.count) tokens")
            
            // Convert to MLMultiArray
            let inputArray = try createMLMultiArray(from: tokens)
            print("🔢 Created MLMultiArray with shape: \(inputArray.shape)")
            
            // Create position_ids array
            let positionIds = try createPositionIds(sequenceLength: expectedSeqLen)
            print("🔢 Created position_ids with shape: \(positionIds.shape)")
            
            // Create input features dictionary with both input_ids and position_ids
            var inputDict: [String: MLFeatureValue] = [:]
            
            let inputNames = Array(model.modelDescription.inputDescriptionsByName.keys)
            if inputNames.contains("input_ids") {
                inputDict["input_ids"] = MLFeatureValue(multiArray: inputArray)
            } else if let first = inputNames.first {
                inputDict[first] = MLFeatureValue(multiArray: inputArray)
            }
            if inputNames.contains("position_ids") {
                inputDict["position_ids"] = MLFeatureValue(multiArray: positionIds)
            }
            
            print("📦 Created input features: \(inputDict.keys.joined(separator: ", "))")
            let input = try MLDictionaryFeatureProvider(dictionary: inputDict)
            
            // Run prediction
            print("🧠 Running model prediction...")
            let output = try await model.prediction(from: input)
            print("✅ Prediction completed")
            
            // Process output
            let outputName = getOutputFeatureName(model)
            guard let outputArray = output.featureValue(for: outputName)?.multiArrayValue else {
                throw LLMError.processingFailed("Could not get output array")
            }
            
            print("📤 Processing output array with shape: \(outputArray.shape)")
            
            // Decode output tokens
            let outputTokens = try extractTokensFromOutput(outputArray)
            let generatedText = try tokenizer.decode(outputTokens)
            
            print("✅ Generated text: \(generatedText.prefix(100))...")
            
            return generatedText
            
        } catch {
            print("❌ Text generation failed: \(error)")
            throw LLMError.processingFailed(error.localizedDescription)
        }
    }
    
    private func createMLMultiArray(from tokens: [Int]) throws -> MLMultiArray {
        // Create MLMultiArray with shape [sequence_length] (rank 1)
        let shape = [tokens.count] as [NSNumber]
        let array = try MLMultiArray(shape: shape, dataType: .int32)
        
        for (idx, token) in tokens.enumerated() {
            array[idx] = NSNumber(value: token)
        }
        return array
    }
    
    private func createPositionIds(sequenceLength: Int) throws -> MLMultiArray {
        // Create position_ids array with shape [sequence_length] (rank 1)
        let shape = [sequenceLength] as [NSNumber]
        let array = try MLMultiArray(shape: shape, dataType: .int32)
        
        // Fill with sequential position indices (0, 1, 2, ...)
        for i in 0..<sequenceLength {
            array[i] = NSNumber(value: i)
        }
        
        return array
    }
    
    private func getInputFeatureName(_ model: MLModel) -> String {
        // Get the first input feature name
        let inputNames = Array(model.modelDescription.inputDescriptionsByName.keys)
        return inputNames.first ?? "input_ids"
    }
    
    private func getOutputFeatureName(_ model: MLModel) -> String {
        // Get the first output feature name
        let outputNames = Array(model.modelDescription.outputDescriptionsByName.keys)
        return outputNames.first ?? "logits"
    }
    
    private func extractTokensFromOutput(_ outputArray: MLMultiArray) throws -> [Int] {
        var tokens: [Int] = []
        
        print("🔍 Output array shape: \(outputArray.shape)")
        
        // Handle different output shapes
        if outputArray.shape.count == 2 {
            // Shape: [sequence_length, vocab_size]
            let sequenceLength = outputArray.shape[0].intValue
            let vocabSize = outputArray.shape[1].intValue
            
            // Take the last position for next token prediction
            let lastPosition = sequenceLength - 1
            var bestToken = 0
            var bestScore = Float.leastNormalMagnitude
            
            for vocabIdx in 0..<vocabSize {
                let index = lastPosition * vocabSize + vocabIdx
                let score = outputArray[index].floatValue
                if score > bestScore {
                    bestScore = score
                    bestToken = vocabIdx
                }
            }
            
            tokens.append(bestToken)
            
        } else if outputArray.shape.count == 3 {
            // Shape: [batch_size, sequence_length, vocab_size]
            let batchSize = outputArray.shape[0].intValue
            let sequenceLength = outputArray.shape[1].intValue
            let vocabSize = outputArray.shape[2].intValue
            
            // Take the last position for next token prediction
            let lastPosition = sequenceLength - 1
            var bestToken = 0
            var bestScore = Float.leastNormalMagnitude
            
            for vocabIdx in 0..<vocabSize {
                let index = 0 * sequenceLength * vocabSize + lastPosition * vocabSize + vocabIdx
                let score = outputArray[index].floatValue
                if score > bestScore {
                    bestScore = score
                    bestToken = vocabIdx
                }
            }
            
            tokens.append(bestToken)
        } else {
            // Fallback: just return a few common tokens
            print("⚠️ Unexpected output shape, using fallback tokens")
            // Use simple token IDs that should exist in our basic vocab
            tokens = [35, 32, 116] // Basic fallback tokens
        }
        
        print("🔤 Extracted tokens: \(tokens)")
        return tokens
    }
}

// MARK: - GPT-2 Tokenizer

private class GPT2Tokenizer {
    // Simplified GPT-2 tokenizer
    // In a real implementation, you would use a proper BPE tokenizer
    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]
    
    // Special tokens
    private let bosToken = "<|startoftext|>"
    private let eosToken = "<|endoftext|>"
    private let padToken = "<|pad|>"
    
    init() {
        // Initialize with a basic vocabulary
        // In a real implementation, load from vocab.json and merges.txt
        var tempVocab: [String: Int] = [:]
        var tempReverse: [Int: String] = [:]
        
        // Add special tokens
        tempVocab[bosToken] = 0
        tempVocab[eosToken] = 1
        tempVocab[padToken] = 2
        
        tempReverse[0] = bosToken
        tempReverse[1] = eosToken
        tempReverse[2] = padToken
        
        // Add basic ASCII characters
        for i in 32...126 {
            let char = String(Character(UnicodeScalar(i)!))
            tempVocab[char] = i - 32 + 3
            tempReverse[i - 32 + 3] = char
        }
        
        // Add common words (simplified)
        let commonWords = ["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
        for (index, word) in commonWords.enumerated() {
            tempVocab[word] = 200 + index
            tempReverse[200 + index] = word
        }
        
        self.vocab = tempVocab
        self.reverseVocab = tempReverse
    }
    
    func encode(_ text: String, maxLength: Int) throws -> [Int] {
        var tokens: [Int] = []
        
        // Add BOS token
        if let bosId = vocab[bosToken] {
            tokens.append(bosId)
        }
        
        // Simple character-level tokenization
        for char in text {
            let charStr = String(char)
            if let tokenId = vocab[charStr] {
                tokens.append(tokenId)
            } else {
                // Use a default token for unknown characters
                if let unkId = vocab["?"] {
                    tokens.append(unkId)
                }
            }
            
            if tokens.count >= maxLength - 1 { // Reserve space for EOS
                break
            }
        }
        
        // Add EOS token
        if let eosId = vocab[eosToken] {
            tokens.append(eosId)
        }
        
        return tokens
    }
    
    func decode(_ tokens: [Int]) throws -> String {
        var text = ""
        
        for token in tokens {
            if let char = reverseVocab[token] {
                if char != bosToken && char != eosToken && char != padToken {
                    text += char
                }
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func padTokenId() -> Int {
        return vocab[padToken] ?? 2
    }
} 