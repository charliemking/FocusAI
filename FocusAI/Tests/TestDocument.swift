import XCTest
@testable import FocusAI

final class DocumentTests: XCTestCase {
    var persistence: PersistenceController!
    var searchService: SearchService!
    var documentShare: DocumentShare!
    
    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        searchService = SearchService.shared
        documentShare = DocumentShare.shared
    }
    
    override func tearDown() {
        persistence = nil
        super.tearDown()
    }
    
    func testDocumentProcessing() async throws {
        // Create test document
        let document = Document(
            source: .text("This is a test document for search functionality"),
            title: "Test Document"
        )
        
        // Process document
        await document.process()
        
        // Verify document was saved
        let stored = try persistence.fetchDocument(withID: document.id)
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.title, "Test Document")
        XCTAssertEqual(stored?.content, "This is a test document for search functionality")
    }
    
    func testDocumentSearch() async throws {
        // Create and process multiple documents
        let doc1 = Document(source: .text("Apple fruit is healthy"), title: "Apple")
        let doc2 = Document(source: .text("Banana is yellow"), title: "Banana")
        
        await doc1.process()
        await doc2.process()
        
        // Search for documents
        let results = try await searchService.searchDocuments(query: "Apple")
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Apple")
    }
    
    func testDocumentSharing() async throws {
        // Create and process a document
        let document = Document(
            source: .text("Test content for sharing"),
            title: "Share Test"
        )
        await document.process()
        
        // Prepare for sharing
        try await document.prepareForSharing()
        
        // Verify share URL was created
        XCTAssertNotNil(document.shareURL)
        
        // Import shared document
        if let shareURL = document.shareURL {
            let imported = try await Document.importDocument(from: shareURL)
            
            // Verify imported document matches original
            XCTAssertEqual(imported.title, document.title)
            XCTAssertEqual(imported.content, document.content)
        }
    }
    
    func testSearchPerformance() async throws {
        // Create 100 test documents
        for i in 0..<100 {
            let doc = Document(
                source: .text("Test document \(i) with searchable content"),
                title: "Test \(i)"
            )
            await doc.process()
        }
        
        // Measure search performance
        measure {
            Task {
                do {
                    let _ = try await searchService.searchDocuments(query: "searchable")
                } catch {
                    XCTFail("Search failed: \(error)")
                }
            }
        }
    }
    
    func testDocumentExportFormat() async throws {
        // Create document with all features
        let document = Document(source: .text("Test content"), title: "Export Test")
        await document.process()
        
        // Add summary
        try await document.saveSummary("Test summary")
        
        // Add flashcards
        try await document.saveFlashcards([
            ("Q1", "A1"),
            ("Q2", "A2")
        ])
        
        // Export document
        try await document.prepareForSharing()
        
        guard let shareURL = document.shareURL else {
            XCTFail("Share URL not created")
            return
        }
        
        // Verify file format
        let data = try Data(contentsOf: shareURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // This will throw if the format is invalid
        let _ = try decoder.decode(ExportableDocument.self, from: data)
    }
} 