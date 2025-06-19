import SwiftUI

public struct DiagnosticsView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var diagnosticsText = "Loading diagnostics..."
    @State private var testResults = ""
    @State private var isRunningTest = false
    @State private var selectedTest: TestType = .inference
    
    private enum TestType: String, CaseIterable {
        case inference = "Inference Test"
        case summary = "Summary Test"
        case question = "Q&A Test"
        case flashcards = "Flashcard Test"
        
        var description: String {
            switch self {
            case .inference:
                return "Basic model inference test"
            case .summary:
                return "Test summary generation"
            case .question:
                return "Test question answering"
            case .flashcards:
                return "Test flashcard generation"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("🔍 Model Diagnostics")
                .font(.title)
                .foregroundColor(Theme.primaryColor)
            
            // Model Status Section
            VStack(alignment: .leading, spacing: 10) {
                Text("📊 Current Status")
                    .font(.headline)
                    .foregroundColor(Theme.primaryColor)
                
                ScrollView {
                    Text(diagnosticsText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color(.darkGray))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            // Test Section
            VStack(alignment: .leading, spacing: 10) {
                Text("🧪 Run Tests")
                    .font(.headline)
                    .foregroundColor(Theme.primaryColor)
                
                HStack {
                    Picker("Test Type", selection: $selectedTest) {
                        ForEach(TestType.allCases, id: \.self) { test in
                            Text(test.rawValue).tag(test)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Spacer()
                    
                    Button(action: runSelectedTest) {
                        HStack {
                            if isRunningTest {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isRunningTest ? "Running..." : "Run Test")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isRunningTest)
                }
                
                if !testResults.isEmpty {
                    ScrollView {
                        Text(testResults)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(.darkGray))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 300)
                }
            }
            
            Spacer()
            
            // Refresh Button
            Button("🔄 Refresh Diagnostics") {
                loadDiagnostics()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(.controlAccentColor))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(20)
        .onAppear {
            loadDiagnostics()
        }
        .navigationTitle("Diagnostics")
    }
    
    private func loadDiagnostics() {
        Task {
            await MainActor.run {
                if let embeddedLLM = serviceManager.llmInterface as? EmbeddedLLMInterface {
                    diagnosticsText = embeddedLLM.getModelDiagnostics()
                } else {
                    diagnosticsText = """
                    🔍 FocusAI Model Diagnostics
                    ===========================
                    
                    ⚠️ Using \(type(of: serviceManager.llmInterface))
                    
                    📊 Service Status:
                    • Initialized: \(serviceManager.isInitialized)
                    • Processing: \(serviceManager.isProcessing)
                    • Model status: \(serviceManager.modelStatus)
                    • Last error: \(serviceManager.lastError?.localizedDescription ?? "None")
                    
                    💡 Note: Detailed diagnostics only available with EmbeddedLLMInterface
                    """
                }
            }
        }
    }
    
    private func runSelectedTest() {
        isRunningTest = true
        testResults = ""
        
        Task {
            let startTime = Date()
            var results = """
            🧪 \(selectedTest.rawValue) - \(Date().formatted(.dateTime))
            ================================================================
            
            """
            
            do {
                switch selectedTest {
                case .inference:
                    results += await runInferenceTest()
                case .summary:
                    results += await runSummaryTest()
                case .question:
                    results += await runQuestionTest()
                case .flashcards:
                    results += await runFlashcardTest()
                }
            } catch {
                results += "❌ Test failed with error: \(error.localizedDescription)\n"
            }
            
            let duration = Date().timeIntervalSince(startTime)
            results += "\n⏱️ Total test duration: \(String(format: "%.2f", duration))s"
            
            await MainActor.run {
                testResults = results
                isRunningTest = false
                // Refresh diagnostics to see updated stats
                loadDiagnostics()
            }
        }
    }
    
    private func runInferenceTest() async -> String {
        if let embeddedLLM = serviceManager.llmInterface as? EmbeddedLLMInterface {
            let (success, details) = await embeddedLLM.testInference()
            return """
            📋 Basic Inference Test:
            \(details)
            
            🎯 Result: \(success ? "✅ PASSED" : "❌ FAILED")
            """
        } else {
            return "⚠️ Inference test only available with EmbeddedLLMInterface"
        }
    }
    
    private func runSummaryTest() async -> String {
        let testText = """
        Artificial intelligence (AI) has become one of the most transformative technologies of the 21st century. 
        Machine learning, a subset of AI, enables computers to learn and make decisions from data without being 
        explicitly programmed for every task. Deep learning, which uses neural networks with multiple layers, 
        has revolutionized fields like computer vision, natural language processing, and speech recognition. 
        Companies like Google, Microsoft, and OpenAI are leading the development of large language models that 
        can understand and generate human-like text.
        """
        
        do {
            let startTime = Date()
            let summary = try await serviceManager.llmInterface.generateSummary(text: testText)
            let duration = Date().timeIntervalSince(startTime)
            
            let wordCount = summary.split(separator: " ").count
            let charCount = summary.count
            
            return """
            📝 Summary Generation Test:
            
            📊 Input: \(testText.count) characters
            ⏱️ Duration: \(String(format: "%.2f", duration))s
            📏 Output: \(charCount) characters, \(wordCount) words
            
            📄 Generated Summary:
            "\(summary)"
            
            🎯 Result: \(summary.count > 20 ? "✅ PASSED" : "❌ FAILED (too short)")
            """
        } catch {
            return "❌ Summary test failed: \(error.localizedDescription)"
        }
    }
    
    private func runQuestionTest() async -> String {
        let context = """
        The Renaissance was a period of European history from the 14th to 17th century, marking the transition 
        from the Middle Ages to modernity. It began in Italy and later spread throughout Europe. The Renaissance 
        was characterized by a renewed interest in classical learning, humanism, art, and science. Key figures 
        included Leonardo da Vinci, Michelangelo, and Galileo Galilei.
        """
        
        let question = "What was the Renaissance and when did it occur?"
        
        do {
            let startTime = Date()
            let answer = try await serviceManager.llmInterface.askQuestion(question, context: context)
            let duration = Date().timeIntervalSince(startTime)
            
            let wordCount = answer.split(separator: " ").count
            let charCount = answer.count
            
            return """
            ❓ Question Answering Test:
            
            📋 Question: "\(question)"
            📊 Context: \(context.count) characters
            ⏱️ Duration: \(String(format: "%.2f", duration))s
            📏 Output: \(charCount) characters, \(wordCount) words
            
            💬 Generated Answer:
            "\(answer)"
            
            🎯 Result: \(answer.count > 10 ? "✅ PASSED" : "❌ FAILED (too short)")
            """
        } catch {
            return "❌ Q&A test failed: \(error.localizedDescription)"
        }
    }
    
    private func runFlashcardTest() async -> String {
        let testText = """
        Photosynthesis is the process by which plants convert sunlight into chemical energy. This process occurs 
        in the chloroplasts of plant cells and involves two main stages: the light-dependent reactions and the 
        Calvin cycle. During photosynthesis, plants absorb carbon dioxide from the air and water from the soil, 
        using sunlight energy to convert these into glucose and oxygen. The chemical equation for photosynthesis 
        is: 6CO2 + 6H2O + light energy → C6H12O6 + 6O2.
        """
        
        do {
            let startTime = Date()
            let flashcards = try await serviceManager.llmInterface.generateFlashcards(text: testText)
            let duration = Date().timeIntervalSince(startTime)
            
            var result = """
            🃏 Flashcard Generation Test:
            
            📊 Input: \(testText.count) characters
            ⏱️ Duration: \(String(format: "%.2f", duration))s
            📇 Generated: \(flashcards.count) flashcards
            
            """
            
            for (index, card) in flashcards.enumerated() {
                result += """
                Card \(index + 1):
                Q: \(card.question)
                A: \(card.answer)
                
                """
            }
            
            result += "🎯 Result: \(flashcards.count > 0 ? "✅ PASSED" : "❌ FAILED (no flashcards)")"
            
            return result
        } catch {
            return "❌ Flashcard test failed: \(error.localizedDescription)"
        }
    }
}

