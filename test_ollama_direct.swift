#!/usr/bin/env swift

import Foundation

// Simple direct test of Ollama
func testOllamaDirectly() async {
    print("🧪 Testing Ollama directly...")
    
    // Test 1: Health check
    print("1. Testing health check...")
    do {
        let url = URL(string: "http://localhost:11434/api/tags")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   Status code: \(httpResponse.statusCode)")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = json?["models"] as? [[String: Any]] ?? []
        print("   Available models: \(models.count)")
        
        for model in models {
            if let name = model["name"] as? String {
                print("   - \(name)")
            }
        }
    } catch {
        print("   ❌ Health check failed: \(error)")
        return
    }
    
    // Test 2: Simple generation
    print("2. Testing text generation...")
    do {
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "phi3",
            "prompt": "Hello, how are you?",
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   Status code: \(httpResponse.statusCode)")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let responseText = json?["response"] as? String {
            print("   Response: \(responseText.prefix(100))...")
        } else {
            print("   ❌ No response text found")
            print("   Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
        }
        
    } catch {
        print("   ❌ Generation test failed: \(error)")
    }
    
    print("✅ Test complete")
}

// Run the test
Task {
    await testOllamaDirectly()
    exit(0)
} 