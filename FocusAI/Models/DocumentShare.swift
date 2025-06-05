import Foundation

class DocumentShare {
    static let shared = DocumentShare()
    
    private init() {}
    
    func importDocument(from url: URL) async throws -> Document {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportedDoc = try decoder.decode(ExportableDocument.self, from: data)
        let document = Document(source: .text(exportedDoc.content), title: exportedDoc.title)
        
        // Process and index the document
        await document.process()
        
        return document
    }
    
    func prepareDocumentForSharing(_ document: Document) async throws -> URL {
        // In a real app, this would prepare the document for sharing
        // For now, just return a dummy URL
        return URL(string: "https://example.com/share/\(document.id)")!
    }
} 