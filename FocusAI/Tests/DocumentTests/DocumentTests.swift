import XCTest
@testable import FocusAI

final class DocumentTests: XCTestCase {
    var document: Document!
    
    override func setUp() {
        super.setUp()
        document = Document(source: .text("Test content"), title: "Test Document")
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    func testDocumentCreation() {
        XCTAssertNotNil(document)
        XCTAssertEqual(document.title, "Test Document")
        XCTAssertEqual(document.content, "Test content")
    }
    
    func testDocumentProcessing() async throws {
        await document.process()
        // Verify that the document was indexed
        // In a real test, we would check the search index
    }
    
    func testDocumentSharing() async throws {
        try await document.prepareForSharing()
        XCTAssertNotNil(document.shareURL)
        
        // Verify the file exists
        if let shareURL = document.shareURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: shareURL.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: shareURL)
        }
    }
} 