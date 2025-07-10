import Foundation
import CoreML
import NaturalLanguage

/// App Store compliant AI interface using Apple's Core ML and Natural Language frameworks
/// This replaces the embedded llama.cpp approach with Apple's native solutions
public class CoreMLLLMInterface: LLMInterface {
    
    // MARK: - Properties
    private let summarizer = NLSummarizer()
    private let tagger: NLTagger
    private let tokenizer: NLTokenizer
    
    // MARK: - Initialization
    
    public init() {
        // Initialize Natural Language processing tools
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        self.tokenizer = NLTokenizer(unit: .sentence)
        
        print("🤖 CoreMLLLMInterface initialized with Apple's frameworks")
    }
    
    // MARK: - LLMInterface Implementation
    
    public func loadModel() async throws {
        // No model loading needed - Apple's frameworks are always available
        print("✅ Apple's Core ML and Natural Language frameworks ready")
    }
    
    public func generateSummary(text: String) async throws -> String {
        print("📝 Generating summary using Apple's NaturalLanguage framework...")
        
        // Use Apple's built-in summarization if available (iOS 13+)
        if #available(macOS 10.15, *) {
            let candidates = try await summarizer.candidates(for: text)
            if let bestSummary = candidates.first {
                return bestSummary
            }
        }
        
        // Fallback: Create summary using key sentence extraction
        return extractivesummarization(text: text)
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        print("❓ Answering question using context analysis...")
        
        // Extract relevant sentences from context
        let relevantSentences = findRelevantSentences(question: question, context: context)
        
        if relevantSentences.isEmpty {
            return "I couldn't find relevant information in the provided context to answer your question."
        }
        
        // Create a contextual answer
        let answer = createContextualAnswer(question: question, sentences: relevantSentences)
        return answer
    }
    
    public func generateFlashcards(text: String, count: Int = 5) async throws -> [Flashcard] {
        print("🃏 Generating flashcards using named entity recognition...")
        
        var flashcards: [Flashcard] = []
        
        // Extract key concepts using NLTagger
        let keyTerms = extractKeyTerms(from: text)
        let namedEntities = extractNamedEntities(from: text)
        let definitions = extractDefinitions(from: text)
        
        // Create flashcards from named entities
        for entity in namedEntities.prefix(count / 2) {
            let context = findContextForEntity(entity: entity, in: text)
            if !context.isEmpty {
                flashcards.append(Flashcard(
                    question: "What is \(entity)?",
                    answer: context,
                ))
            }
        }
        
        // Create flashcards from definitions
        for definition in definitions.prefix(count / 2) {
            flashcards.append(Flashcard(
                question: "Define: \(definition.term)",
                answer: definition.definition,
            ))
        }
        
        // Fill remaining slots with key term questions
        let remainingSlots = max(0, count - flashcards.count)
        for term in keyTerms.prefix(remainingSlots) {
            let context = findContextForEntity(entity: term, in: text)
            if !context.isEmpty {
                flashcards.append(Flashcard(
                    question: "Explain the concept of \(term)",
                    answer: context,
                ))
            }
        }
        
        return flashcards
    }
    
    // MARK: - Helper Methods
    
    private func extractivesummarization(text: String) -> String {
        // Split into sentences
        tokenizer.string = text
        let sentences = tokenizer.tokens(for: text.startIndex..<text.endIndex).map { range in
            String(text[range])
        }
        
        // Score sentences by keyword density and position
        let keyTerms = extractKeyTerms(from: text)
        let scoredSentences = sentences.enumerated().map { index, sentence in
            let score = scoreSentence(sentence, keyTerms: keyTerms, position: index, totalSentences: sentences.count)
            return (sentence: sentence, score: score)
        }
        
        // Select top sentences
        let topSentences = scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0.sentence }
        
        return topSentences.joined(separator: " ")
    }
    
    private func scoreSentence(_ sentence: String, keyTerms: [String], position: Int, totalSentences: Int) -> Double {
        var score = 0.0
        
        // Keyword matching
        for term in keyTerms {
            if sentence.localizedCaseInsensitiveContains(term) {
                score += 1.0
            }
        }
        
        // Position bonus (first and last sentences often important)
        if position == 0 || position == totalSentences - 1 {
            score += 0.5
        }
        
        // Length penalty (avoid very short sentences)
        if sentence.count < 50 {
            score -= 0.3
        }
        
        return score
    }
    
    private func extractKeyTerms(from text: String) -> [String] {
        tagger.string = text
        var terms: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            guard let tag = tag else { return true }
            
            let word = String(text[range])
            
            // Include nouns and proper nouns
            if tag == .noun || tag == .other {
                if word.count > 3 && !word.allSatisfy({ $0.isNumber }) {
                    terms.append(word)
                }
            }
            
            return true
        }
        
        // Return most frequent terms
        let termCounts = Dictionary(grouping: terms, by: { $0.lowercased() })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        return Array(termCounts)
    }
    
    private func extractNamedEntities(from text: String) -> [String] {
        tagger.string = text
        var entities: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            guard let tag = tag else { return true }
            
            let entity = String(text[range])
            
            // Include persons, places, organizations
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                entities.append(entity)
            }
            
            return true
        }
        
        return Array(Set(entities)) // Remove duplicates
    }
    
    private func extractDefinitions(from text: String) -> [(term: String, definition: String)] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var definitions: [(term: String, definition: String)] = []
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for definition patterns
            if let definition = extractDefinitionFromSentence(trimmed) {
                definitions.append(definition)
            }
        }
        
        return definitions
    }
    
    private func extractDefinitionFromSentence(_ sentence: String) -> (term: String, definition: String)? {
        // Pattern: "X is Y" or "X means Y"
        let patterns = [
            "(.+) is (.+)",
            "(.+) means (.+)",
            "(.+) refers to (.+)",
            "(.+) can be defined as (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: sentence, options: [], range: NSRange(location: 0, length: sentence.count))
                
                if let match = matches.first, match.numberOfRanges == 3 {
                    let term = String(sentence[Range(match.range(at: 1), in: sentence)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let definition = String(sentence[Range(match.range(at: 2), in: sentence)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if term.count > 2 && definition.count > 10 {
                        return (term: term, definition: definition)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findRelevantSentences(question: String, context: String) -> [String] {
        let sentences = context.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Extract key terms from question
        let questionTerms = extractKeyTerms(from: question)
        
        // Score sentences by relevance to question
        let scoredSentences = sentences.map { sentence in
            let score = questionTerms.reduce(0.0) { score, term in
                return score + (sentence.localizedCaseInsensitiveContains(term) ? 1.0 : 0.0)
            }
            return (sentence: sentence, score: score)
        }
        
        // Return top 3 most relevant sentences
        return scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(3)
            .compactMap { $0.score > 0 ? $0.sentence : nil }
    }
    
    private func createContextualAnswer(question: String, sentences: [String]) -> String {
        // Simple approach: return the most relevant sentence
        if let bestSentence = sentences.first {
            return bestSentence
        }
        
        return "Based on the provided context: " + sentences.joined(separator: " ")
    }
    
    private func findContextForEntity(entity: String, in text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Find sentence containing the entity
        for sentence in sentences {
            if sentence.localizedCaseInsensitiveContains(entity) {
                return sentence
            }
        }
        
        return ""
    }
}

// MARK: - Flashcard Difficulty Extension

extension Flashcard {
    /// Determines difficulty based on content complexity
    static func determineDifficulty(for content: String) -> FlashcardDifficulty {
        let wordCount = content.components(separatedBy: .whitespaces).count
        let complexity = content.components(separatedBy: CharacterSet.alphanumerics.inverted).count
        
        if wordCount > 30 || complexity > 20 {
            return .advanced
        } else if wordCount > 15 || complexity > 10 {
            return .intermediate
        } else {
            return .basic
        }
    }
} 