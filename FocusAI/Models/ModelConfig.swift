import Foundation

struct ModelConfig {
    static let modelPath = Bundle.main.path(forResource: "model", ofType: "mlc", inDirectory: "models/mistral") ?? ""
    
    static let contextWindow = 4096
    
    static let defaultGenerationSettings = GenerationSettings(
        temperature: 0.7,
        topP: 0.95,
        repetitionPenalty: 1.1,
        maxTokens: 2048
    )
}

struct GenerationSettings {
    let temperature: Float
    let topP: Float
    let repetitionPenalty: Float
    let maxTokens: Int
} 