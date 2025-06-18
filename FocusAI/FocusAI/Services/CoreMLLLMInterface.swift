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
    }
    
    public func loadModel() async throws {
        guard model == nil else {
            print("✅ CoreML model already loaded")
            return
        }
        
        do {
            print("🔄 Loading CoreML model: \(modelName)")
            
            // Load the model from the main bundle
            guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") else {
                throw LLMError.modelLoadFailed("Model file not found in bundle")
            }
            
            print("📁 Model path: \(modelURL.path)")
            
            // Load the CoreML model
            let loadedModel = try MLModel(contentsOf: modelURL)
            self.model = loadedModel
            
            // Initialize tokenizer
            self.tokenizer = GPT2Tokenizer()
            
            // Print model information
            await printModelInfo(loadedModel)
            
            print("✅ CoreML model loaded successfully")
            
        } catch {
            print("❌ Failed to load CoreML model: \(error)")
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
        
        let prompt = """
        Context: \(context.prefix(300))
        
        Question: \(question)
        
        Answer:
        """
        
        return try await generateText(from: prompt)
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isModelLoaded() else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = """
        Please summarize the following text:
        
        \(text.prefix(400))
        
        Summary:
        """
        
        return try await generateText(from: prompt)
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
            
            // Tokenize input
            let tokens = try tokenizer.encode(prompt, maxLength: maxSequenceLength)
            print("📝 Tokenized input: \(tokens.count) tokens")
            
            // Convert to MLMultiArray
            let inputArray = try createMLMultiArray(from: tokens)
            print("🔢 Created MLMultiArray with shape: \(inputArray.shape)")
            
            // Create input feature
            let inputName = getInputFeatureName(model)
            let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(multiArray: inputArray)])
            print("📦 Created input feature: \(inputName)")
            
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
        // Create MLMultiArray with shape [1, sequence_length]
        let shape = [1, tokens.count] as [NSNumber]
        let array = try MLMultiArray(shape: shape, dataType: .int32)
        
        // Fill the array with tokens
        for i in 0..<tokens.count {
            array[i] = NSNumber(value: tokens[i])
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
        
        // For now, take the argmax of the last sequence position
        // This is a simplified approach - in reality, you'd implement proper sampling
        let sequenceLength = outputArray.shape[1].intValue
        let vocabSize = outputArray.shape[2].intValue
        
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
} 