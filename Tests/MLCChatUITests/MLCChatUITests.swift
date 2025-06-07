import XCTest

final class MLCChatUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testChatViewInteraction() {
        // Test message input
        let messageField = app.textFields["Type a message..."]
        XCTAssertTrue(messageField.exists)
        
        messageField.tap()
        messageField.typeText("Hello, AI!")
        
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()
        
        // Wait for response
        let predicate = NSPredicate(format: "exists == true")
        let responseElement = app.staticTexts.containing(predicate)
        
        let expectation = expectation(
            for: predicate,
            evaluatedWith: responseElement,
            handler: nil
        )
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testModelSelection() {
        // Test model list view
        let modelList = app.collectionViews["ModelList"]
        XCTAssertTrue(modelList.exists)
        
        if modelList.cells.count > 0 {
            let firstModel = modelList.cells.element(boundBy: 0)
            firstModel.tap()
            
            // Verify chat view appears
            let chatView = app.otherElements["ChatView"]
            XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        }
    }
    
    func testErrorHandling() {
        // Test error display
        let modelList = app.collectionViews["ModelList"]
        if modelList.cells.count > 0 {
            let firstModel = modelList.cells.element(boundBy: 0)
            firstModel.tap()
            
            // Force an error by sending an empty message
            let sendButton = app.buttons["Send"]
            if sendButton.exists {
                sendButton.tap()
                
                // Verify error message appears
                let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Error'"))
                XCTAssertTrue(errorMessage.element.waitForExistence(timeout: 5))
            }
        }
    }
    
    func testModelDownloadProgress() {
        // Test download progress indicator
        let downloadButton = app.buttons["Download Model"]
        if downloadButton.exists {
            downloadButton.tap()
            
            // Verify progress indicator appears
            let progressIndicator = app.progressIndicators.firstMatch
            XCTAssertTrue(progressIndicator.waitForExistence(timeout: 5))
            
            // Wait for download to complete
            let completionIndicator = app.staticTexts["Download Complete"]
            XCTAssertTrue(completionIndicator.waitForExistence(timeout: 30))
        }
    }
} 