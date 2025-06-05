import Foundation
import PDFKit
import CoreData
import UIKit
import CoreSpotlight

enum DocumentSource: Codable, Equatable {
    case pdf(URL)
    case text(String)
    case url(URL)
    
    var sourceType: String {
        switch self {
        case .pdf: return "pdf"
        case .text: return "text"
        case .url: return "url"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, url, text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "pdf":
            let url = try container.decode(URL.self, forKey: .url)
            self = .pdf(url)
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "url":
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .pdf(let url):
            try container.encode("pdf", forKey: .type)
            try container.encode(url, forKey: .url)
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .url(let url):
            try container.encode("url", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}

class Document: Identifiable, ObservableObject, Codable {
    let id: UUID
    let source: DocumentSource
    let title: String
    @Published var content: String = ""
    @Published var isProcessing = false
    @Published var error: Error?
    @Published var summary: String?
    @Published var flashcards: [Flashcard] = []
    @Published var isSharing = false
    @Published var shareURL: URL?
    
    private let analytics = Analytics.shared
    private let persistence = PersistenceController.shared
    private let documentShare = DocumentShare.shared
    
    private enum CodingKeys: String, CodingKey {
        case id, source, title, content, summary, flashcards, shareURL
    }
    
    init(id: UUID = UUID(), source: DocumentSource, title: String) {
        self.id = id
        self.source = source
        self.title = title
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(DocumentSource.self, forKey: .source)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        flashcards = try container.decodeIfPresent([Flashcard].self, forKey: .flashcards) ?? []
        shareURL = try container.decodeIfPresent(URL.self, forKey: .shareURL)
        
        analytics = Analytics.shared
        persistence = PersistenceController.shared
        documentShare = DocumentShare.shared
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(flashcards, forKey: .flashcards)
        try container.encodeIfPresent(shareURL, forKey: .shareURL)
    }
    
    @MainActor
    func process() async {
        isProcessing = true
        let startTime = Date()
        
        do {
            switch source {
            case .pdf(let url):
                try await extractPDFContent(from: url)
            case .text(let text):
                content = text
            case .url(let url):
                try await extractURLContent(from: url)
            }
            
            await analytics.logUsage(.documentProcessed(id: id, type: source.sourceType))
            isProcessing = false
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: true,
                errorDescription: nil
            ))
            
        } catch {
            self.error = error
            isProcessing = false
            
            await analytics.logUsage(.error(description: error.localizedDescription))
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: false,
                errorDescription: error.localizedDescription
            ))
        }
    }
    
    private func extractPDFContent(from url: URL) async throws {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.pdfExtractionFailed
        }
        
        var text = ""
        let pageCount = pdfDocument.pageCount
        for i in 0..<pageCount {
            if let page = pdfDocument.page(at: i) {
                if let pageText = page.string {
                    text += pageText + "\n"
                }
            }
        }
        
        if text.isEmpty {
            throw DocumentError.pdfExtractionFailed
        }
        
        content = text
    }
    
    private func extractURLContent(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentError.urlContentFailed
        }
        content = text
    }
    
    @MainActor
    func save() async throws {
        let startTime = Date()
        
        do {
            if let stored = try persistence.fetchDocument(withID: id) {
                try persistence.updateDocument(stored, with: self)
            } else {
                try persistence.createDocument(from: self)
            }
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: true,
                errorDescription: nil
            ))
            
        } catch {
            await analytics.logUsage(.error(description: error.localizedDescription))
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: false,
                errorDescription: error.localizedDescription
            ))
            
            throw error
        }
    }
    
    @MainActor
    func saveSummary(_ summary: String) async throws {
        let startTime = Date()
        
        do {
            if let stored = try persistence.fetchDocument(withID: id) {
                try persistence.saveSummary(summary, for: stored)
                self.summary = summary
                
                await analytics.logUsage(.summaryGenerated(id: id))
            }
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: true,
                errorDescription: nil
            ))
            
        } catch {
            await analytics.logUsage(.error(description: error.localizedDescription))
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: false,
                errorDescription: error.localizedDescription
            ))
            
            throw error
        }
    }
    
    @MainActor
    func saveFlashcards(_ cards: [Flashcard]) async throws {
        let startTime = Date()
        
        do {
            if let stored = try persistence.fetchDocument(withID: id) {
                try persistence.saveFlashcards(cards, for: stored)
                self.flashcards = cards
                
                await analytics.logUsage(.flashcardsGenerated(count: cards.count))
            }
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: true,
                errorDescription: nil
            ))
            
        } catch {
            await analytics.logUsage(.error(description: error.localizedDescription))
            
            await analytics.logPerformance(Analytics.PerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                memoryUsage: await analytics.getCurrentMemoryUsage(),
                success: false,
                errorDescription: error.localizedDescription
            ))
            
            throw error
        }
    }
    
    @MainActor
    func delete() async throws {
        if let stored = try persistence.fetchDocument(withID: id) {
            try persistence.deleteDocument(stored)
        }
    }
    
    @MainActor
    func share() async throws {
        isSharing = true
        
        do {
            if let stored = try persistence.fetchDocument(withID: id) {
                shareURL = try await documentShare.prepareDocumentForSharing(stored)
            }
        } catch {
            throw DocumentError.sharingError(error.localizedDescription)
        }
        
        isSharing = false
    }
}

enum DocumentError: Error {
    case pdfExtractionFailed
    case urlContentFailed
    case invalidURL
    case persistenceError(String)
    case sharingError(String)
}

struct ExportableDocument: Codable {
    let id: UUID
    let title: String
    let content: String
    var summary: String?
    var flashcards: [(String, String)]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case summary
        case flashcards
    }
    
    init(id: UUID, title: String, content: String, summary: String? = nil, flashcards: [(String, String)]? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.summary = summary
        self.flashcards = flashcards
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        flashcards = try container.decodeIfPresent([(String, String)].self, forKey: .flashcards)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(flashcards, forKey: .flashcards)
    }
} 