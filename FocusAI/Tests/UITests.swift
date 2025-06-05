import XCTest

final class FocusAIUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    func testSearchFlow() throws {
        // Wait for model to load
        let modelLoadedExpectation = expectation(
            for: NSPredicate(format: "exists == true"),
            evaluatedWith: app.tabBars["Tab Bar"].buttons["Search"],
            handler: nil
        )
        wait(for: [modelLoadedExpectation], timeout: 30.0)
        
        // Navigate to Documents tab and add a test document
        app.tabBars["Tab Bar"].buttons["Documents"].tap()
        
        // Add test document
        let textField = app.textFields["Enter or paste text"]
        textField.tap()
        textField.typeText("This is a test document with unique content")
        
        app.buttons["Process"].tap()
        
        // Wait for processing
        let processingExpectation = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.activityIndicators["Processing"],
            handler: nil
        )
        wait(for: [processingExpectation], timeout: 10.0)
        
        // Switch to Search tab
        app.tabBars["Tab Bar"].buttons["Search"].tap()
        
        // Perform search
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("unique content")
        
        // Verify results
        let resultCell = app.cells.firstMatch
        XCTAssertTrue(resultCell.waitForExistence(timeout: 5))
        XCTAssertTrue(resultCell.staticTexts["This is a test document with unique content"].exists)
    }
    
    func testDocumentSharing() throws {
        // Wait for model to load
        let modelLoadedExpectation = expectation(
            for: NSPredicate(format: "exists == true"),
            evaluatedWith: app.tabBars["Tab Bar"].buttons["Documents"],
            handler: nil
        )
        wait(for: [modelLoadedExpectation], timeout: 30.0)
        
        // Add test document
        let textField = app.textFields["Enter or paste text"]
        textField.tap()
        textField.typeText("Document for sharing test")
        
        app.buttons["Process"].tap()
        
        // Wait for processing
        let processingExpectation = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.activityIndicators["Processing"],
            handler: nil
        )
        wait(for: [processingExpectation], timeout: 10.0)
        
        // Open document detail
        app.cells.firstMatch.tap()
        
        // Tap share button
        app.buttons["Share"].tap()
        
        // Verify share sheet appears
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
    }
    
    func testSearchPerformance() throws {
        // Wait for model to load
        let modelLoadedExpectation = expectation(
            for: NSPredicate(format: "exists == true"),
            evaluatedWith: app.tabBars["Tab Bar"].buttons["Search"],
            handler: nil
        )
        wait(for: [modelLoadedExpectation], timeout: 30.0)
        
        // Switch to Search tab
        app.tabBars["Tab Bar"].buttons["Search"].tap()
        
        // Measure search performance
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric(),
            XCTClockMetric()
        ]) {
            let searchField = app.searchFields.firstMatch
            searchField.tap()
            searchField.typeText("test")
            
            // Wait for results
            _ = app.cells.firstMatch.waitForExistence(timeout: 2)
            
            // Clear search
            searchField.buttons["Clear text"].tap()
        }
    }
} 