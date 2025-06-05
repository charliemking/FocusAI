import Foundation
import Combine
import os.log

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published private(set) var isModelLoaded = false
    @Published private(set) var loadingProgress: Double = 0
    @Published private(set) var currentError: Error?
    
    private var llmWrapper: LLMWrapper?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "ModelManager")
    private let modelCache = ModelCache.shared
    
    private init() {
        setupNotifications()
    }
    
    func initialize() async {
        do {
            // Get cached model path
            let modelURL = try await modelCache.getCachedModelURL()
            
            // Track progress
            if let progress = modelCache.currentProgress {
                progress.publisher(for: \.fractionCompleted)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] fraction in
                        self?.loadingProgress = fraction
                    }
                    .store(in: &cancellables)
            }
            
            // Initialize LLMWrapper with cached model
            llmWrapper = try LLMWrapper(modelPath: modelURL.path)
            isModelLoaded = true
            currentError = nil
            
            // Clean up old cached models
            try await modelCache.cleanCache()
        } catch {
            currentError = error
            isModelLoaded = false
            logger.error("Failed to initialize model: \(error.localizedDescription)")
        }
    }
    
    func getLLMWrapper() throws -> LLMWrapper {
        guard let wrapper = llmWrapper, isModelLoaded else {
            throw ModelError.modelNotInitialized
        }
        return wrapper
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundTransition),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundTransition),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // Release model if not actively in use
        if !isActivelyGenerating {
            llmWrapper = nil
            isModelLoaded = false
        }
    }
    
    @objc private func handleBackgroundTransition() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Release model in background if not actively generating
        if !isActivelyGenerating {
            llmWrapper = nil
            isModelLoaded = false
        }
    }
    
    @objc private func handleForegroundTransition() {
        Task {
            await initialize()
        }
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // Track active generation to prevent model unloading during generation
    private var isActivelyGenerating = false
    
    func performGeneration<T>(_ operation: (LLMWrapper) async throws -> T) async throws -> T {
        let wrapper = try getLLMWrapper()
        isActivelyGenerating = true
        defer { isActivelyGenerating = false }
        return try await operation(wrapper)
    }
}

enum ModelError: LocalizedError {
    case modelNotInitialized
    case loadingInProgress
    
    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "The language model is not initialized"
        case .loadingInProgress:
            return "Model is currently being loaded"
        }
    }
} 