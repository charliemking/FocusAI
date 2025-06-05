import Foundation

enum ModelConfig {
    static let modelName = "mistral-7b-q4f16_1"
    static let modelVersion = "1.0.0"
    static let contextWindow = 4096
    static let modelPath: String = {
        guard let path = Bundle.main.path(forResource: modelName, ofType: nil) else {
            fatalError("Model file not found in bundle")
        }
        return path
    }()
    
    static let defaultGenerationSettings = GenerationSettings(
        maxTokens: 1024,
        temperature: 0.7,
        topP: 0.9,
        repetitionPenalty: 1.1
    )
}

struct GenerationSettings {
    let maxTokens: Int
    let temperature: Float
    let topP: Float
    let repetitionPenalty: Float
} 