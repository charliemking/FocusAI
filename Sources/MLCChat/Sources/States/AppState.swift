import Foundation
import SwiftUI

public final class AppState: ObservableObject {
    @Published public var modelStates: [ModelState] = []
    @Published public var chatState = ChatState()
    
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private var appConfigURL: URL {
        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("bundle")
        return bundleURL.appendingPathComponent("mlc-app-config.json")
    }
    
    private var modelLocalBaseURL: URL {
        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("bundle")
        return bundleURL
    }
    
    public init() {}
    
    public func loadModels() async throws {
        let data = try Data(contentsOf: appConfigURL)
        let appConfig = try decoder.decode(AppConfig.self, from: data)
        
        modelStates = appConfig.modelList.map { config in
            ModelState(
                modelConfig: config,
                modelLocalBaseURL: modelLocalBaseURL,
                startState: self,
                chatState: chatState
            )
        }
    }
    
    public func addModel(_ config: ModelConfig) {
        let modelState = ModelState(
            modelConfig: config,
            modelLocalBaseURL: modelLocalBaseURL,
            startState: self,
            chatState: chatState
        )
        modelStates.append(modelState)
    }
    
    public func removeModel(_ modelState: ModelState) {
        modelStates.removeAll { $0.modelID == modelState.modelID }
    }
} 