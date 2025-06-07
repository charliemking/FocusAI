import Foundation

public struct ModelConfig: Codable {
    public var tokenizerFiles: [String]?
    public var modelLib: String?
    public var modelID: String?
    public var estimatedVRAMReq: Int?
    
    public init(tokenizerFiles: [String]?, modelLib: String?, modelID: String?, estimatedVRAMReq: Int?) {
        self.tokenizerFiles = tokenizerFiles
        self.modelLib = modelLib
        self.modelID = modelID
        self.estimatedVRAMReq = estimatedVRAMReq
    }
}

public struct ParamsConfig: Codable {
    public let modelPath: String
    public let modelLib: String
    public let modelID: String
    public let estimatedVRAMReq: Int
    
    public init(modelPath: String, modelLib: String, modelID: String, estimatedVRAMReq: Int) {
        self.modelPath = modelPath
        self.modelLib = modelLib
        self.modelID = modelID
        self.estimatedVRAMReq = estimatedVRAMReq
    }
}

public struct AppConfig: Codable {
    public let modelList: [ModelConfig]
    
    public init(modelList: [ModelConfig]) {
        self.modelList = modelList
    }
    
    enum CodingKeys: String, CodingKey {
        case modelList = "model_list"
    }
} 