import Foundation
import CoreSpotlight
import MobileCoreServices
import UIKit

actor SearchService {
    static let shared = SearchService()
    private let searchableIndex = CSSearchableIndex.default()
    
    private init() {}
    
    // MARK: - Indexing
    
    func indexDocument(_ document: StoredDocument) async {
        guard let id = document.id?.uuidString,
              let content = document.content else {
            return
        }
        
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = document.title
        attributeSet.contentDescription = String(content.prefix(200)) // Preview text
        attributeSet.textContent = content
        attributeSet.contentCreationDate = document.createdAt
        attributeSet.contentModificationDate = document.lastAccessed
        
        // Add document type metadata
        attributeSet.contentType = document.sourceType as CFString
        if let path = document.sourcePath {
            attributeSet.path = path
        }
        
        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: "com.focusai.documents",
            attributeSet: attributeSet
        )
        
        do {
            try await searchableIndex.indexSearchableItems([item])
        } catch {
            print("Indexing error: \(error.localizedDescription)")
        }
    }
    
    func removeDocument(withID id: UUID) async {
        do {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: [id.uuidString])
        } catch {
            print("Failed to remove document from index: \(error.localizedDescription)")
        }
    }
    
    func reindexAllDocuments() async {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<StoredDocument> = StoredDocument.fetchRequest()
        
        do {
            // First, delete existing index
            try await searchableIndex.deleteAllSearchableItems()
            
            // Fetch all documents
            let documents = try context.fetch(fetchRequest)
            
            // Reindex each document
            for document in documents {
                await indexDocument(document)
            }
        } catch {
            print("Reindexing error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search
    
    func searchDocuments(query: String) async throws -> [StoredDocument] {
        let context = PersistenceController.shared.container.viewContext
        
        // Create query
        let queryString = "content == \"*\(query)*\"cd OR title == \"*\(query)*\"cd"
        let searchQuery = CSSearchQuery(queryString: queryString,
                                     attributes: ["title", "textContent"])
        
        return try await withCheckedThrowingContinuation { continuation in
            var foundDocuments: [StoredDocument] = []
            
            searchQuery.foundItemsHandler = { items in
                let ids = items.compactMap { UUID(uuidString: $0.uniqueIdentifier) }
                let fetchRequest: NSFetchRequest<StoredDocument> = StoredDocument.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
                
                do {
                    let documents = try context.fetch(fetchRequest)
                    foundDocuments.append(contentsOf: documents)
                } catch {
                    print("Failed to fetch documents: \(error.localizedDescription)")
                }
            }
            
            searchQuery.completionHandler = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: foundDocuments)
                }
            }
            
            searchQuery.start()
        }
    }
} 