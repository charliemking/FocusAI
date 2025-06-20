import Foundation
import OSLog

public class EmbeddedLLMInterface: LLMInterface {
    private let logger = Logger(subsystem: "com.focusai.app", category: "EmbeddedLLM")
    
    // Server configuration
    private let serverPort: Int = 8080
    private var serverProcess: Process?
    private var isLoaded = false
    private var baseURL: String { "http://127.0.0.1:\(self.serverPort)" }
    
    // MARK: - Diagnostic Properties
    private var lastGenerationStats: GenerationStats?
    private var serverStartTime: Date?
    private var serverLogs: [String] = []
    
    public struct GenerationStats {
        let prompt: String
        let rawResponse: String
        let cleanedResponse: String
        let tokenCount: Int
        let duration: TimeInterval
        let usedFallback: Bool
        let fallbackReason: String?
        let timestamp: Date
        
        public var debugDescription: String {
            return """
            📊 Generation Stats (\(timestamp.formatted(.dateTime.hour().minute().second()))):
            📝 Prompt length: \(prompt.count) chars
            ⚡ Duration: \(String(format: "%.2f", duration))s
            🎯 Tokens: \(tokenCount)
            📤 Raw response length: \(rawResponse.count) chars
            ✨ Cleaned response length: \(cleanedResponse.count) chars
            🔄 Used fallback: \(usedFallback) \(fallbackReason != nil ? "(\(fallbackReason!))" : "")
            📄 Raw response preview: "\(String(rawResponse.prefix(100)))..."
            🎨 Final output preview: "\(String(cleanedResponse.prefix(100)))..."
            """
        }
    }
    
    // File paths
    private var llamaCppServerPath: String {
        guard let bundlePath = Bundle.main.path(forResource: "llama-server", ofType: "") else {
            fatalError("llama-server binary not found in app bundle")
        }
        return bundlePath
    }
    
    private var modelPath: String {
        guard let modelPath = Bundle.main.path(forResource: "phi-3-mini-4k-instruct", ofType: "gguf") else {
            fatalError("Phi-3 model not found in app bundle")
        }
        return modelPath
    }
    
    // MARK: - Performance Monitoring
    
    private var performanceMetrics: [String: [Double]] = [:]
    
    private func recordPerformanceMetric(_ operation: String, duration: Double, tokenCount: Int = 0) {
        if performanceMetrics[operation] == nil {
            performanceMetrics[operation] = []
        }
        performanceMetrics[operation]?.append(duration)
        
        let tokensPerSecond = tokenCount > 0 ? Double(tokenCount) / duration : 0
        let message = "⚡ \(operation): \(String(format: "%.2f", duration))s" + (tokensPerSecond > 0 ? " (\(String(format: "%.1f", tokensPerSecond)) tok/s)" : "")
        logger.info("\(message)")
    }
    
    public func getPerformanceReport() -> String {
        var report = """
        🚀 FocusAI Performance Report
        ============================
        
        """
        
        for (operation, durations) in performanceMetrics {
            let average = durations.reduce(0, +) / Double(durations.count)
            let min = durations.min() ?? 0
            let max = durations.max() ?? 0
            
            report += """
            📊 \(operation):
            • Runs: \(durations.count)
            • Average: \(String(format: "%.2f", average))s
            • Best: \(String(format: "%.2f", min))s
            • Worst: \(String(format: "%.2f", max))s
            
            """
        }
        
        // System info
        let cpuCount = ProcessInfo.processInfo.processorCount
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        
        report += """
        💻 System Info:
        • CPU Cores: \(cpuCount)
        • Memory: \(memoryGB) GB
        • Model: Phi-3-mini (CPU-only, thermal-safe)
        """
        
        return report
    }
    
    public func resetPerformanceMetrics() {
        performanceMetrics.removeAll()
        logger.info("🔄 Performance metrics reset")
    }
    
    public init() {
        logger.info("🔧 EmbeddedLLMInterface initialized")
    }
    
    deinit {
        stopServer()
    }
    
    // MARK: - Public Diagnostic Methods
    
    public func getModelDiagnostics() -> String {
        var diagnostics = """
        🔍 FocusAI Model Diagnostics
        ===========================
        
        📊 Server Status:
        • Loaded: \(isLoaded)
        • Process running: \(serverProcess?.isRunning ?? false)
        • Server port: \(serverPort)
        • Start time: \(serverStartTime?.formatted(.dateTime) ?? "Not started")
        
        📁 File Status:
        • Server binary exists: \(FileManager.default.fileExists(atPath: llamaCppServerPath))
        • Model file exists: \(FileManager.default.fileExists(atPath: modelPath))
        • Server path: \(llamaCppServerPath)
        • Model path: \(modelPath)
        
        """
        
        if let stats = lastGenerationStats {
            diagnostics += "\n📈 Last Generation:\n\(stats.debugDescription)\n"
        }
        
        if !serverLogs.isEmpty {
            diagnostics += "\n📋 Recent Server Logs:\n"
            diagnostics += serverLogs.suffix(10).joined(separator: "\n")
        }
        
        // Add performance metrics
        if !performanceMetrics.isEmpty {
            diagnostics += "\n\n" + getPerformanceReport()
        }
        
        return diagnostics
    }
    
    public func testInference() async -> (success: Bool, details: String) {
        guard isLoaded else {
            return (false, "❌ Model not loaded")
        }
        
        let testPrompt = "<|system|>You are a helpful assistant.<|end|>\n<|user|>Write exactly 3 sentences about artificial intelligence.<|end|>\n<|assistant|>"
        
        do {
            let startTime = Date()
            let response = try await generateText(prompt: testPrompt, maxTokens: 100)
            let duration = Date().timeIntervalSince(startTime)
            
            let success = !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            let details = """
            🧪 Inference Test Results:
            ⏱️ Duration: \(String(format: "%.2f", duration))s
            📏 Response length: \(response.count) characters
            ✅ Success: \(success)
            📝 Response: "\(response.prefix(200))..."
            """
            
            return (success, details)
        } catch {
            return (false, "❌ Test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - LLMInterface Implementation
    
    public func loadModel() async throws {
        guard !isLoaded else {
            logger.info("✅ Embedded model already loaded")
            return
        }
        
        serverStartTime = Date()
        
        do {
            logger.info("🔄 Starting embedded llama.cpp server")
            try await startServer()
            
            logger.info("🔄 Waiting for server to be ready...")
            try await waitForServerReady()
            
            logger.info("🔄 Testing model with simple generation...")
            let testPrompt = "<|system|>You are a helpful AI assistant.<|end|>\n<|user|>Hello! Please respond with a brief greeting.<|end|>\n<|assistant|>"
            let testResponse = try await generateText(prompt: testPrompt, maxTokens: 20)
            guard !testResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.modelLoadFailed("Model test failed - no response generated")
            }
            logger.info("✅ Test response: \(testResponse.prefix(50))...")
            
            isLoaded = true
            logger.info("✅ Embedded Phi-3 model loaded successfully")
            
        } catch {
            logger.error("❌ Failed to load embedded model: \(error.localizedDescription)")
            stopServer()
            throw LLMError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    public func isModelLoaded() -> Bool {
        return isLoaded && serverProcess?.isRunning == true
    }
    
    public func askQuestion(_ question: String, context: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildQuestionAnswerPrompt(question: question, context: context)
        
        do {
            let startTime = Date()
            let response = try await generateText(prompt: prompt, maxTokens: 500)
            let duration = Date().timeIntervalSince(startTime)
            let cleanedResponse = cleanGeneratedText(response, for: .questionAnswer)
            
            // More lenient fallback detection - only trigger if really short or empty
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 {
                let fallbackResponse = createFallbackAnswer(question: question, context: context)
                recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: cleanedResponse, 
                                    duration: duration, usedFallback: true, fallbackReason: "Response too short (\(cleanedResponse.count) chars)")
                logger.warning("⚠️ Using fallback for question: response too short (\(cleanedResponse.count) chars)")
                return fallbackResponse
            }
            
            recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: cleanedResponse, 
                                duration: duration, usedFallback: false, fallbackReason: nil)
            logger.info("✅ Question answered successfully in \(String(format: "%.2f", duration))s")
            return cleanedResponse
        } catch {
            let fallbackResponse = createFallbackAnswer(question: question, context: context)
            recordGenerationStats(prompt: prompt, rawResponse: "", cleanedResponse: fallbackResponse, 
                                duration: 0, usedFallback: true, fallbackReason: "Generation failed: \(error.localizedDescription)")
            logger.warning("⚠️ Question answering failed, using fallback: \(error.localizedDescription)")
            return fallbackResponse
        }
    }
    
    public func generateSummary(text: String) async throws -> String {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let startTime = Date()
        
        // Use smart chunking only for very large documents (>8000 chars) - short prompts are faster
        if text.count > 8000 {
            logger.info("📄 Large document detected (\(text.count) chars), using smart chunking for faster processing...")
            
            do {
                let chunks = chunkText(text, maxChunkSize: 1200) // Larger chunks for fewer requests
                logger.info("🔪 Split into \(chunks.count) chunks for sequential processing")
                
                // Process chunks sequentially (server can only handle one at a time anyway)
                var chunkSummaries: [String] = []
                for (index, chunk) in chunks.enumerated() {
                    logger.info("⚡ Processing chunk \(index + 1)/\(chunks.count)...")
                    let summary = try await generateChunkSummary(chunk)
                    chunkSummaries.append(summary)
                }
                
                // Combine the chunk summaries
                let finalSummary = try await combineChunkSummaries(chunkSummaries)
                let duration = Date().timeIntervalSince(startTime)
                
                recordGenerationStats(prompt: "Chunked summary (\(chunks.count) chunks)", 
                                    rawResponse: finalSummary, cleanedResponse: finalSummary, 
                                    duration: duration, usedFallback: false, fallbackReason: nil)
                
                recordPerformanceMetric("Chunked Summary", duration: duration, tokenCount: finalSummary.split(separator: " ").count)
                logger.info("✅ Chunked summary completed in \(String(format: "%.2f", duration))s (was \(chunks.count) sequential chunks)")
                return finalSummary
                
            } catch {
                logger.warning("⚠️ Chunked processing failed, falling back to truncated single pass: \(error)")
                // Fall back to truncated single processing
            }
        }
        
        // Original single-pass processing for smaller documents or fallback
        let prompt = buildSummaryPrompt(text: text)
        
        do {
            let response = try await generateText(prompt: prompt, maxTokens: 400) // Reduced for speed
            let duration = Date().timeIntervalSince(startTime)
            let cleanedResponse = cleanGeneratedText(response, for: .summary)
            
            // More lenient fallback detection - only trigger if really short or empty
            if cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                let fallbackResponse = createFallbackSummary(from: text)
                recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: cleanedResponse, 
                                    duration: duration, usedFallback: true, fallbackReason: "Response too short (\(cleanedResponse.count) chars)")
                logger.warning("⚠️ Using fallback for summary: response too short (\(cleanedResponse.count) chars)")
                return fallbackResponse
            }
            
            recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: cleanedResponse, 
                                duration: duration, usedFallback: false, fallbackReason: nil)
            recordPerformanceMetric("Single Summary", duration: duration, tokenCount: cleanedResponse.split(separator: " ").count)
            logger.info("✅ Summary generated successfully in \(String(format: "%.2f", duration))s")
            return cleanedResponse
        } catch {
            let fallbackResponse = createFallbackSummary(from: text)
            recordGenerationStats(prompt: prompt, rawResponse: "", cleanedResponse: fallbackResponse, 
                                duration: 0, usedFallback: true, fallbackReason: "Generation failed: \(error.localizedDescription)")
            logger.warning("⚠️ Summary generation failed, using fallback: \(error.localizedDescription)")
            return fallbackResponse
        }
    }
    
    public func generateFlashcards(text: String) async throws -> [Flashcard] {
        guard isLoaded else {
            throw LLMError.modelNotLoaded
        }
        
        let prompt = buildFlashcardPrompt(text: text)
        
        do {
            let startTime = Date()
            let response = try await generateText(prompt: prompt, maxTokens: 1500) // Increased from 1000
            let duration = Date().timeIntervalSince(startTime)
            
            // Debug logging to see what we're getting
            logger.info("🔍 Raw flashcard response (\(response.count) chars): \(String(response.prefix(200)))...")
            
            let flashcards = parseFlashcards(from: response)
            
            // Debug logging for parsing results
            logger.info("🎯 Parsed \(flashcards.count) flashcards from response")
            
            if flashcards.isEmpty {
                logger.warning("⚠️ No flashcards parsed from response, trying enhanced parsing...")
                let enhancedFlashcards = parseFlashcardsEnhanced(from: response)
                
                if !enhancedFlashcards.isEmpty {
                    logger.info("✅ Enhanced parsing found \(enhancedFlashcards.count) flashcards")
                    recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: "Generated \(enhancedFlashcards.count) flashcards (enhanced parsing)", 
                                        duration: duration, usedFallback: false, fallbackReason: nil)
                    return enhancedFlashcards
                }
                
                let fallbackFlashcards = createFallbackFlashcards(from: text)
                recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: "Generated \(fallbackFlashcards.count) fallback flashcards", 
                                    duration: duration, usedFallback: true, fallbackReason: "No flashcards parsed from response")
                logger.warning("⚠️ Using fallback flashcards: no flashcards parsed from response")
                return fallbackFlashcards
            }
            
            recordGenerationStats(prompt: prompt, rawResponse: response, cleanedResponse: "Generated \(flashcards.count) flashcards", 
                                duration: duration, usedFallback: false, fallbackReason: nil)
            logger.info("✅ Generated \(flashcards.count) flashcards successfully in \(String(format: "%.2f", duration))s")
            return flashcards
        } catch {
            let fallbackFlashcards = createFallbackFlashcards(from: text)
            recordGenerationStats(prompt: prompt, rawResponse: "", cleanedResponse: "Generated \(fallbackFlashcards.count) fallback flashcards", 
                                duration: 0, usedFallback: true, fallbackReason: "Generation failed: \(error.localizedDescription)")
            logger.warning("⚠️ Flashcard generation failed, using fallback: \(error.localizedDescription)")
            return fallbackFlashcards
        }
    }
    
    // MARK: - Server Management
    
    private func startServer() async throws {
        // If server is already running, don't restart it
        if let existingProcess = serverProcess, existingProcess.isRunning {
            logger.info("✅ Server already running, skipping startup...")
            return
        }
        
        // Clean up any dead process references
        if let existingProcess = serverProcess, !existingProcess.isRunning {
            logger.info("🔄 Cleaning up dead server process...")
            serverProcess = nil
            isLoaded = false
        }
        
        // Simple cleanup: kill any existing llama-server processes if needed
        let killCommand = "pkill -f 'llama-server.*8080' || true"
        let killProcess = Process()
        killProcess.launchPath = "/bin/bash"
        killProcess.arguments = ["-c", killCommand]
        try? killProcess.run()
        killProcess.waitUntilExit()
        
        // Brief wait for cleanup
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        logger.info("✅ Ready to start server...")
        
        // Log file paths for debugging
        logger.info("🔍 Server executable path: \(self.llamaCppServerPath)")
        logger.info("🔍 Model path: \(self.modelPath)")
        
        // Verify files exist
        guard FileManager.default.fileExists(atPath: llamaCppServerPath) else {
            throw LLMError.modelLoadFailed("Server executable not found at: \(llamaCppServerPath)")
        }
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LLMError.modelLoadFailed("Model file not found at: \(modelPath)")
        }
        
        // Create the server process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: llamaCppServerPath)
        
        // Optimized server arguments for better CPU performance (no GPU to avoid overheating)
        let cpuCount = ProcessInfo.processInfo.processorCount
        let performanceCores = max(2, min(cpuCount / 2, 4)) // Use only performance cores, conservative threading
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        let contextSize = memoryGB >= 16 ? 8192 : 4096 // Larger context for better caching
        
        process.arguments = [
            "--model", modelPath,
            "--port", "\(self.serverPort)",
            "--host", "127.0.0.1",
            "--ctx-size", "\(contextSize)", // Increased context for better caching
            "--threads", "\(performanceCores)", // Conservative threading to avoid overheating
            "--n-gpu-layers", "0", // NO GPU - keep it CPU-only for thermal safety
            "--batch-size", "512", // Optimized batch size for stability
            "--ubatch-size", "256", // Optimized micro-batch size
            "--n-predict", "-1", // Don't limit predictions
            "--temp", "0.7",
            "--top-p", "0.9",
            "--repeat-penalty", "1.1",
            "--mlock", // Lock model in memory for speed
            "--verbose", // Enable verbose logging for debugging
        ]
        
        logger.info("🔍 Server arguments: \(process.arguments ?? [])")
        
        // Create pipes for capturing output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment variables and library search path
        var environment = ProcessInfo.processInfo.environment
        
        // Add library search path for bundled dylibs
        if let resourcePath = Bundle.main.resourcePath {
            if let existingDyldPath = environment["DYLD_LIBRARY_PATH"] {
                environment["DYLD_LIBRARY_PATH"] = "\(resourcePath):\(existingDyldPath)"
            } else {
                environment["DYLD_LIBRARY_PATH"] = resourcePath
            }
            logger.info("🔍 Library search path: \(resourcePath)")
        }
        
        process.environment = environment
        
        logger.info("🔍 Starting process...")
        
        do {
            try process.run()
            serverProcess = process
            
            logger.info("🚀 llama.cpp server started on port \(self.serverPort)")
            
            // Start background task to capture server logs
            Task.detached { [weak self] in
                await self?.captureServerLogs(outputPipe: outputPipe, errorPipe: errorPipe)
            }
            
            // Check if process is still running after a short delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if !process.isRunning {
                // Capture any error output
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "No error output"
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let standardOutput = String(data: outputData, encoding: .utf8) ?? "No standard output"
                
                logger.error("❌ Server process terminated immediately")
                logger.error("❌ Error output: \(errorOutput)")
                logger.error("❌ Standard output: \(standardOutput)")
                
                throw LLMError.modelLoadFailed("Server failed to start within timeout period")
            }
            
        } catch {
            logger.error("❌ Failed to start server process: \(error)")
            throw LLMError.modelLoadFailed("Failed to start server: \(error.localizedDescription)")
        }
    }
    
    private func captureServerLogs(outputPipe: Pipe, errorPipe: Pipe) async {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // Capture standard output
        Task {
            while serverProcess?.isRunning == true {
                let data = outputHandle.availableData
                if !data.isEmpty, let logLine = String(data: data, encoding: .utf8) {
                    await addServerLog("📤 OUT: \(logLine.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        // Capture error output
        Task {
            while serverProcess?.isRunning == true {
                let data = errorHandle.availableData
                if !data.isEmpty, let logLine = String(data: data, encoding: .utf8) {
                    await addServerLog("🔥 ERR: \(logLine.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private func addServerLog(_ log: String) async {
        await MainActor.run {
            serverLogs.append("[\(Date().formatted(.dateTime.hour().minute().second()))] \(log)")
            // Keep only last 50 log entries
            if serverLogs.count > 50 {
                serverLogs.removeFirst(10)
            }
        }
    }
    
    private func stopServer() {
        logger.info("🛑 Starting server cleanup...")
        
        // First, terminate our specific process if it exists
        if let process = serverProcess, process.isRunning {
            logger.info("🛑 Stopping our llama.cpp server process (PID: \(process.processIdentifier))")
            process.terminate()
            
            // Wait for graceful termination
            let deadline = Date().addingTimeInterval(5.0)
            while process.isRunning && Date() < deadline {
                usleep(100_000) // 0.1 seconds
            }
            
            // Force kill if still running
            if process.isRunning {
                logger.warning("⚠️ Force killing our llama.cpp server")
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        // Only kill other llama-server processes if they're conflicting
        if isPortInUseByOtherProcess(self.serverPort) {
            logger.info("🔥 Killing conflicting llama-server processes...")
            let killAllCommand = "pkill -f llama-server"
            let killProcess = Process()
            killProcess.launchPath = "/bin/bash"
            killProcess.arguments = ["-c", killAllCommand]
            try? killProcess.run()
            killProcess.waitUntilExit()
            
            // Wait for port to be freed
            var attempts = 0
            while isPortInUseByOtherProcess(self.serverPort) && attempts < 10 {
                logger.info("⏳ Waiting for port \(self.serverPort) to be freed... (attempt \(attempts + 1))")
                usleep(500_000) // 0.5 seconds
                attempts += 1
            }
        }
        
        serverProcess = nil
        isLoaded = false
        logger.info("✅ Server cleanup completed (port free: \(!self.isPortInUse(self.serverPort)))")
    }
    
    private func waitForServerReady() async throws {
        let maxAttempts = 60 
        var attempts = 0
        
        while attempts < maxAttempts {
            do {
                let url = URL(string: "http://127.0.0.1:\(serverPort)/health")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 10 
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    logger.info("Server is ready after \(attempts + 1) attempts")
                    return
                }
            } catch {
                // Continue trying
            }
            
            attempts += 1
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds between attempts
        }
        
        throw LLMError.modelLoadFailed("Server failed to start within timeout period")
    }
    
    private func isPortInUse(_ port: Int) -> Bool {
        let checkCommand = "lsof -i :\(port) | grep LISTEN"
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", checkCommand]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func isPortInUseByOtherProcess(_ port: Int) -> Bool {
        let checkCommand = "lsof -i :\(port) | grep LISTEN"
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", checkCommand]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // If no output, port is free
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.isEmpty {
            return false
        }
        
        // If we have our own server process, check if the port is used by our PID
        if let ourProcess = serverProcess {
            let ourPID = String(ourProcess.processIdentifier)
            // If the output contains our PID, the port is used by our process (which is fine)
            if output.contains(ourPID) {
                logger.info("🔍 Port \(port) is in use by our own process (PID: \(ourPID))")
                return false
            }
        }
        
        logger.info("🔍 Port \(port) is in use by another process: \(trimmedOutput)")
        return true
    }
    
    // MARK: - Text Generation
    
    private func generateText(prompt: String, maxTokens: Int = 300) async throws -> String {
        let url = URL(string: "\(baseURL)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "n_predict": maxTokens,
            "temperature": 0.7,
            "top_p": 0.9,
            "top_k": 40,
            "repeat_penalty": 1.1,
            "stream": false,
            "stop": ["<|end|>", "<|user|>"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        logger.info("🌐 Making generation request (maxTokens: \(maxTokens), prompt length: \(prompt.count))")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.processingFailed("Invalid response")
            }
            
            logger.info("📡 Server response: HTTP \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                logger.error("❌ Server error: \(errorBody)")
                throw LLMError.processingFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let generatedText = json?["content"] as? String ?? ""
            
            logger.info("✨ Generated text length: \(generatedText.count) chars")
            if generatedText.count < 50 {
                logger.warning("⚠️ Short generation: '\(generatedText)'")
            }
            
            return generatedText
        } catch {
            logger.error("❌ Generation request failed: \(error.localizedDescription)")
            throw LLMError.processingFailed("Failed to generate text: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Smart Document Chunking for Performance
    
    private func chunkText(_ text: String, maxChunkSize: Int = 800) -> [String] {
        // Preprocess text to remove artifacts and optimize tokens
        let cleanedText = preprocessText(text)
        
        // Split by paragraphs first, then by sentences if needed
        let paragraphs = cleanedText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var chunks: [String] = []
        var currentChunk = ""
        
        for paragraph in paragraphs {
            // If paragraph is too long, split by sentences
            if paragraph.count > maxChunkSize {
                let sentences = paragraph.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                for sentence in sentences {
                    if currentChunk.count + sentence.count + 2 > maxChunkSize {
                        if !currentChunk.isEmpty {
                            chunks.append(currentChunk)
                            currentChunk = sentence
                        }
                    } else {
                        if !currentChunk.isEmpty {
                            currentChunk += ". " + sentence
                        } else {
                            currentChunk = sentence
                        }
                    }
                }
            } else {
                // Add whole paragraph if it fits
                if currentChunk.count + paragraph.count + 2 > maxChunkSize {
                    if !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                        currentChunk = paragraph
                    }
                } else {
                    if !currentChunk.isEmpty {
                        currentChunk += "\n\n" + paragraph
                    } else {
                        currentChunk = paragraph
                    }
                }
            }
        }
        
        // Add the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
    
    private func generateChunkSummary(_ chunk: String) async throws -> String {
        // Much shorter prompt for faster processing
        let prompt = """
        <|system|>Summarize in 2-3 sentences.<|end|>
        <|user|>\(chunk)

        Summary:<|end|>
        <|assistant|>
        """
        
        let response = try await generateText(prompt: prompt, maxTokens: 100) // Reduced tokens
        return cleanGeneratedText(response, for: .summary)
    }
    
    private func combineChunkSummaries(_ summaries: [String]) async throws -> String {
        let combinedSummaries = summaries.joined(separator: "\n\n")
        
        // Shorter prompt for faster processing
        let prompt = """
        <|system|>Combine into one comprehensive summary.<|end|>
        <|user|>\(combinedSummaries)

        Unified summary:<|end|>
        <|assistant|>
        """
        
        let response = try await generateText(prompt: prompt, maxTokens: 400) // Reduced tokens
        return cleanGeneratedText(response, for: .summary)
    }
    
    // MARK: - Utility Methods
    
    private func recordGenerationStats(prompt: String, rawResponse: String, cleanedResponse: String, 
                                     duration: TimeInterval, usedFallback: Bool, fallbackReason: String?) {
        let tokenCount = rawResponse.split(separator: " ").count // Rough token estimate
        lastGenerationStats = GenerationStats(
            prompt: String(prompt.prefix(200)), // Store first 200 chars of prompt
            rawResponse: rawResponse,
            cleanedResponse: cleanedResponse,
            tokenCount: tokenCount,
            duration: duration,
            usedFallback: usedFallback,
            fallbackReason: fallbackReason,
            timestamp: Date()
        )
    }
    
    // MARK: - Prompt Building
    
         private func buildSummaryPrompt(text: String) -> String {
         let cleanedText = preprocessText(text)
         let truncatedText = String(cleanedText.prefix(4000)) // Aggressively reduced for speed
         return """
         <|system|>Create a comprehensive summary.<|end|>
         <|user|>\(truncatedText)

         Summary:<|end|>
         <|assistant|>
         """
     }
    
    private func buildQuestionAnswerPrompt(question: String, context: String) -> String {
        let truncatedContext = String(context.prefix(10000)) // Reduced from 12000 for faster processing
        return """
        <|system|>You are a knowledgeable research assistant that provides thorough, accurate answers based on the given context. Analyze the context carefully and provide detailed, well-reasoned responses. Use specific information from the context to support your answers.<|end|>
        <|user|>Context for reference:
        \(truncatedContext)

        Question: \(question)

        Please provide a comprehensive answer based on the context above. Include specific details and explain your reasoning.<|end|>
        <|assistant|>
        """
    }
    
    private func buildFlashcardPrompt(text: String) -> String {
        let truncatedText = String(text.prefix(10000))
        return """
        <|system|>You are creating educational flashcards. You must format each flashcard exactly as shown in the example. Use the exact format with Q: and A: prefixes.<|end|>
        <|user|>Create exactly 5-7 flashcards from this content:

        \(truncatedText)

        You must format each flashcard exactly like this example:
        Q: What is the main concept discussed?
        A: The main concept is artificial intelligence, which refers to machines that can perform tasks requiring human intelligence.

        Q: What are the key benefits mentioned?
        A: The key benefits include improved efficiency, automated decision-making, and enhanced data analysis capabilities.

        Important: Use only Q: and A: prefixes. Do not use numbers, bullets, or other formatting. Create 5-7 flashcards now:<|end|>
        <|assistant|>Q:
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
        
        // Remove common AI prefixes
        let prefixesToRemove = [
            "Here's a summary:",
            "Summary:",
            "Here is a summary:",
            "Here is an example summary:",
            "Based on the provided context:",
            "Answer:",
            "Here's the answer:",
        ]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return cleaned
    }
    
    private func parseFlashcards(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        
        // Clean the text first - remove system tokens and extra content
        let cleanedText = text
            .replacingOccurrences(of: "<\\|[^|]+\\|>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "Create exactly \\d+ flashcards.*?:", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First, try regex-based parsing for better reliability
        let patterns = [
            // Pattern 1: Q: ... A: ... (with multiline support)
            "Q:\\s*([^\\n]+(?:\\n(?!Q:|A:)[^\\n]*)*?)\\s*A:\\s*([^\\n]+(?:\\n(?!Q:|A:)[^\\n]*)*?)(?=\\s*Q:|$)",
            // Pattern 2: Question: ... Answer: ...
            "Question:\\s*([^\\n]+(?:\\n(?!Question:|Answer:)[^\\n]*)*?)\\s*Answer:\\s*([^\\n]+(?:\\n(?!Question:|Answer:)[^\\n]*)*?)(?=\\s*Question:|$)",
            // Pattern 3: Numbered format 1. Q: ... A: ...
            "\\d+\\.\\s*Q:\\s*([^\\n]+(?:\\n(?!\\d+\\.|Q:|A:)[^\\n]*)*?)\\s*A:\\s*([^\\n]+(?:\\n(?!\\d+\\.|Q:|A:)[^\\n]*)*?)(?=\\s*\\d+\\.|$)"
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = regex?.matches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.utf16.count)) ?? []
            
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let questionRange = match.range(at: 1)
                    let answerRange = match.range(at: 2)
                    
                    if let questionNSRange = Range(questionRange, in: cleanedText),
                       let answerNSRange = Range(answerRange, in: cleanedText) {
                        let question = String(cleanedText[questionNSRange])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        let answer = String(cleanedText[answerNSRange])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        
                        if !question.isEmpty && !answer.isEmpty && question.count > 5 && answer.count > 5 {
                            flashcards.append(Flashcard(question: question, answer: answer))
                        }
                    }
                }
            }
            
            // If we found flashcards with this pattern, use them
            if !flashcards.isEmpty {
                break
            }
        }
        
        // Fallback to line-by-line parsing if regex failed
        if flashcards.isEmpty {
            flashcards = parseFlashcardsLineByLine(from: cleanedText)
        }
        
        // Final cleanup and validation
        return flashcards.map { flashcard in
            let cleanQuestion = flashcard.question
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanAnswer = flashcard.answer
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Flashcard(question: cleanQuestion, answer: cleanAnswer, tags: flashcard.tags)
        }.filter { $0.question.count >= 5 && $0.answer.count >= 5 }
    }
    
    // Enhanced parsing method for when standard parsing fails
    private func parseFlashcardsEnhanced(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        
        // Try to find any Q/A patterns more aggressively
        let lines = text.components(separatedBy: .newlines)
        var currentQuestion: String?
        var currentAnswer: String?
        var collectingAnswer = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Look for question indicators
            if trimmed.range(of: "^(Q:|Question:|\\d+\\.\\s*Q:)", options: [.regularExpression, .caseInsensitive]) != nil {
                // Save previous flashcard
                if let q = currentQuestion, let a = currentAnswer, q.count > 5, a.count > 5 {
                    flashcards.append(Flashcard(question: q, answer: a))
                }
                
                // Extract question
                currentQuestion = trimmed
                    .replacingOccurrences(of: "^(Q:|Question:|\\d+\\.\\s*Q:)\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = nil
                collectingAnswer = false
                
            } else if trimmed.range(of: "^(A:|Answer:)", options: [.regularExpression, .caseInsensitive]) != nil {
                // Extract answer
                currentAnswer = trimmed
                    .replacingOccurrences(of: "^(A:|Answer:)\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                collectingAnswer = true
                
            } else if collectingAnswer && currentAnswer != nil {
                // Continue building answer
                currentAnswer! += " " + trimmed
            } else if currentQuestion != nil && currentAnswer == nil {
                // Continue building question
                currentQuestion! += " " + trimmed
            }
        }
        
        // Add the last flashcard
        if let q = currentQuestion, let a = currentAnswer, q.count > 5, a.count > 5 {
            flashcards.append(Flashcard(question: q, answer: a))
        }
        
        return flashcards
    }
    
    private func parseFlashcardsLineByLine(from text: String) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentQuestion: String?
        var currentAnswer: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            if trimmed.lowercased().hasPrefix("q:") {
                // Save previous flashcard if complete
                if let q = currentQuestion, let a = currentAnswer, !q.isEmpty, !a.isEmpty {
                    flashcards.append(Flashcard(question: q, answer: a))
                }
                
                currentQuestion = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = nil
            } else if trimmed.lowercased().hasPrefix("a:") {
                currentAnswer = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.lowercased().hasPrefix("question:") {
                // Save previous flashcard if complete
                if let q = currentQuestion, let a = currentAnswer, !q.isEmpty, !a.isEmpty {
                    flashcards.append(Flashcard(question: q, answer: a))
                }
                
                currentQuestion = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentAnswer = nil
            } else if trimmed.lowercased().hasPrefix("answer:") {
                currentAnswer = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentQuestion != nil && currentAnswer == nil {
                // Continue building the question if we haven't found an answer yet
                currentQuestion! += " " + trimmed
            } else if currentAnswer != nil {
                // Continue building the answer
                currentAnswer! += " " + trimmed
            }
        }
        
        // Add the last flashcard
        if let q = currentQuestion, let a = currentAnswer, !q.isEmpty, !a.isEmpty {
            flashcards.append(Flashcard(question: q, answer: a))
        }
        
        return flashcards
    }
    
    // MARK: - Fallback Methods
    
    private func createFallbackAnswer(question: String, context: String) -> String {
        return """
        Based on the provided context, here's what I can tell you about your question:
        
        **Question:** \(question)
        
        **Answer:** The context discusses relevant information that helps address your question. While I cannot provide a complete AI-generated response at this moment, I encourage you to review the key sections of the material that relate to: \(extractKeyTerms(from: context).prefix(3).joined(separator: ", ")).
        
        For the most accurate information, please refer to the original source material.
        """
    }
    
    private func createFallbackSummary(from text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }
            .prefix(3)
        
        if sentences.isEmpty {
            return "Summary: The provided text contains information about \(extractKeyTerms(from: text).prefix(3).joined(separator: ", ")). Please review the original content for detailed information."
        }
        
        return sentences.joined(separator: ". ") + "."
    }
    
    private func createFallbackFlashcards(from text: String) -> [Flashcard] {
        let keyTerms = extractKeyTerms(from: text).prefix(6)
        return keyTerms.map { term in
            Flashcard(
                question: "What is \(term)?",
                answer: "Based on the provided text, \(term) is an important concept. Please review the source material for detailed information."
            )
        }
    }
    
    private func extractKeyTerms(from text: String) -> [String] {
        let commonWords = Set([
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "a", "an", "is", "are", "was", "were", "be", "been", "have", "has", "had"
        ])
        
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in
                word.count >= 4 &&
                word.count <= 20 &&
                !commonWords.contains(word) &&
                !word.allSatisfy { $0.isNumber }
            }
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        return Array(wordCounts)
    }
    
    // MARK: - Streaming Text Generation for Better UX
    
    public func generateTextWithProgress(
        prompt: String, 
        maxTokens: Int = 500,
        onProgress: @escaping (String) -> Void
    ) async throws -> String {
        guard isLoaded else {
            throw LLMError.processingFailed("Model not loaded")
        }
        
        let url = URL(string: "\(baseURL)/completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "n_predict": maxTokens,
            "temperature": 0.7,
            "top_p": 0.9,
            "repeat_penalty": 1.1,
            "stream": true // Enable streaming
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.processingFailed("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMError.processingFailed("HTTP \(httpResponse.statusCode)")
        }
        
        var fullResponse = ""
        var buffer = ""
        
        for try await byte in asyncBytes {
            buffer.append(Character(UnicodeScalar(byte) ?? UnicodeScalar(32)!))
            
            // Process complete lines
            if buffer.contains("\n") {
                let lines = buffer.components(separatedBy: "\n")
                buffer = lines.last ?? ""
                
                for line in lines.dropLast() {
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" {
                            break
                        }
                        
                        if let data = jsonString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let content = json["content"] as? String {
                            fullResponse += content
                            
                            // Call progress callback with accumulated text
                            let currentResponse = fullResponse
                            await MainActor.run {
                                onProgress(currentResponse)
                            }
                        }
                    }
                }
            }
        }
        
        return fullResponse
    }
    
    // MARK: - Text Preprocessing for Efficiency
    
    private func preprocessText(_ text: String) -> String {
        var processed = text
        
        // Remove excessive whitespace
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove multiple consecutive newlines
        processed = processed.replacingOccurrences(of: "\\n\\s*\\n\\s*\\n+", with: "\n\n", options: .regularExpression)
        
        // Remove leading/trailing whitespace from lines
        let lines = processed.components(separatedBy: .newlines)
        processed = lines.map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
        
        // Remove common PDF artifacts that waste tokens
        let artifactsToRemove = [
            "Page \\d+", // Page numbers
            "\\d+/\\d+", // Page ratios
            "©.*?\\d{4}", // Copyright notices
            "www\\.\\S+", // URLs (keep content, remove URLs)
            "https?://\\S+", // HTTP URLs
        ]
        
        for pattern in artifactsToRemove {
            processed = processed.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 
