import XCTest
import TestCore
import MLCChatTestSupport
@testable import MLCChat

final class MLCChatTests: XCTestCase {
    var mockMLCSwift: MockMLCSwift!
    var chatState: TestChatState!
    var bridge: MLCChatTestBridge!
    
    override func setUp() {
        super.setUp()
        mockMLCSwift = MockMLCSwift()
        chatState = TestChatState()
        bridge = MLCChatTestBridge(chatState: chatState, mlcSwift: mockMLCSwift)
    }
    
    override func tearDown() {
        bridge = nil
        mockMLCSwift = nil
        chatState = nil
        super.tearDown()
    }
    
    func testMessageProcessing() async throws {
        let userMessage = "Hello, how are you?"
        mockMLCSwift.mockResponse = "I'm doing well, thank you!"
        
        let response = try await bridge.processUserMessage(userMessage)
        
        // Verify messages in chat state
        XCTAssertEqual(chatState.messages.count, 2)
        XCTAssertEqual(chatState.messages[0].content, userMessage)
        XCTAssertEqual(chatState.messages[0].role, .user)
        XCTAssertEqual(chatState.messages[1].content, "I'm doing well, thank you!")
        XCTAssertEqual(chatState.messages[1].role, .assistant)
        
        // Verify MLCSwift interaction
        XCTAssertEqual(mockMLCSwift.lastPrompt, userMessage)
        XCTAssertEqual(response, "I'm doing well, thank you!")
    }
    
    func testChatStateManagement() {
        // Test adding messages
        let message1 = Message(content: "Hello", role: .user)
        let message2 = Message(content: "Hi there", role: .assistant)
        
        chatState.addMessage(message1)
        chatState.addMessage(message2)
        
        XCTAssertEqual(chatState.messages.count, 2)
        XCTAssertEqual(chatState.messages[0], message1)
        XCTAssertEqual(chatState.messages[1], message2)
        
        // Test clearing messages
        bridge.reset()
        XCTAssertTrue(chatState.messages.isEmpty)
        XCTAssertFalse(mockMLCSwift.modelLoaded)
    }
    
    func testMLCSwiftIntegration() {
        XCTAssertFalse(mockMLCSwift.modelLoaded)
        
        let success = mockMLCSwift.loadModel()
        XCTAssertTrue(success)
        XCTAssertTrue(mockMLCSwift.modelLoaded)
        
        let prompt = "Test prompt"
        mockMLCSwift.mockResponse = "Test response"
        let response = mockMLCSwift.generate(prompt: prompt)
        
        XCTAssertEqual(mockMLCSwift.lastPrompt, prompt)
        XCTAssertEqual(response, "Test response")
    }
} 