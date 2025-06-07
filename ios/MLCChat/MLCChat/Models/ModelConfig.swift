//
//  ModelConfig.swift
//  MLCChat
//

import Foundation

struct ModelConfig: Codable {
    let tokenizerFiles: [String]?
    let modelLib: String?
    let modelID: String?
    let estimatedVRAMReq: Int?
    
    init(tokenizerFiles: [String]?, modelLib: String?, modelID: String?, estimatedVRAMReq: Int?) {
        self.tokenizerFiles = tokenizerFiles
        self.modelLib = modelLib
        self.modelID = modelID
        self.estimatedVRAMReq = estimatedVRAMReq
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tokenizerFiles = try container.decode([String]?.self, forKey: .tokenizerFiles)
        self.modelLib = try container.decode(String?.self, forKey: .modelLib)
        self.modelID = try container.decode(String?.self, forKey: .modelID)
        self.estimatedVRAMReq = try container.decode(Int?.self, forKey: .estimatedVRAMReq)
    }
    
    enum CodingKeys: String, CodingKey {
        case tokenizerFiles
        case modelLib
        case modelID
        case estimatedVRAMReq
    }
}
