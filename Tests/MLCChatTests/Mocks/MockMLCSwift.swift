import Foundation

/// A mock implementation of MLCSwift for testing purposes
public class MockMLCSwift {
    public static var shared = MockMLCSwift()
    
    public var modelLoaded = false
    public var lastPrompt: String?
    public var mockResponse = "Mock response from MLCSwift"
    
    public func loadModel() -> Bool {
        modelLoaded = true
        return true
    }
    
    public func generate(prompt: String) -> String {
        lastPrompt = prompt
        return mockResponse
    }
    
    public func reset() {
        modelLoaded = false
        lastPrompt = nil
        mockResponse = "Mock response from MLCSwift"
    }
} 