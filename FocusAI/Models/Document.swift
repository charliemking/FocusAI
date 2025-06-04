import Foundation

struct Document: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let source: DocumentSource
    var summary: String?
    var flashcards: [Flashcard]?
    var dateCreated: Date
    
    init(id: UUID = UUID(), title: String, content: String, source: DocumentSource) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.dateCreated = Date()
    }
}

enum DocumentSource: Codable {
    case pdf(URL)
    case text
    case url(URL)
    
    // Custom coding keys for proper encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case type, url
    }
    
    enum SourceType: String, Codable {
        case pdf, text, url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)
        
        switch type {
        case .pdf:
            let url = try container.decode(URL.self, forKey: .url)
            self = .pdf(url)
        case .text:
            self = .text
        case .url:
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .pdf(let url):
            try container.encode(SourceType.pdf, forKey: .type)
            try container.encode(url, forKey: .url)
        case .text:
            try container.encode(SourceType.text, forKey: .type)
        case .url(let url):
            try container.encode(SourceType.url, forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
} 