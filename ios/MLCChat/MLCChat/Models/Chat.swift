import Foundation
import MLCSwift

class Chat {
    private let engine: LLMEngine
    
    init() throws {
        self.engine = try LLMEngine()
    }
    
    func generate(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        engine.generate(prompt: prompt, completion: completion)
    }
    
    func reset() {
        engine.reset()
    }
} 