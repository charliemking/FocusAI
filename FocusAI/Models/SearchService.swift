import Foundation
import CoreSpotlight
import Combine

class SearchService: ObservableObject {
    static let shared = SearchService()
    
    @Published var searchResults: [Document] = []
    @Published var isSearching = false
    @Published var searchError: Error?
    
    private init() {}
    
    func searchDocuments(query: String) async throws -> [Document] {
        await MainActor.run { isSearching = true }
        defer { Task { @MainActor in isSearching = false } }
        
        let queryString = "title == \"*\(query)*\"c || content == \"*\(query)*\"c"
        let searchQuery = CSSearchQuery(
            queryString: queryString,
            attributes: ["title", "content"]
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            searchQuery.foundItemsHandler = { items in
                // Process found items
                let documents = items.compactMap { item -> Document? in
                    guard let id = UUID(uuidString: item.uniqueIdentifier),
                          let title = item.attributeSet.title,
                          let content = item.attributeSet.contentDescription else {
                        return nil
                    }
                    return Document(id: id, source: .text(content), title: title)
                }
                Task { @MainActor in
                    self.searchResults = documents
                }
                continuation.resume(returning: documents)
            }
            
            searchQuery.completionHandler = { error in
                if let error = error {
                    Task { @MainActor in
                        self.searchError = error
                    }
                    continuation.resume(throwing: error)
                }
            }
            
            searchQuery.start()
        }
    }
    
    func indexDocument(_ document: StoredDocument) async {
        // Implementation for document indexing
    }
} 