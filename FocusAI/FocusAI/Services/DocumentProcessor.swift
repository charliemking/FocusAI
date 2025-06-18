import Foundation
import PDFKit

public protocol DocumentProcessor {
    func extractText(from pdf: PDFDocument) async throws -> String
    func extractText(from url: URL) async throws -> String
    func processDocument(pdf: PDFDocument) async throws -> ProcessedDocument
    func processDocument(url: URL) async throws -> ProcessedDocument
    func processDocument(text: String) async throws -> ProcessedDocument
}

public class DefaultDocumentProcessor: DocumentProcessor {
    private let llmInterface: LLMInterface
    
    public init(llmInterface: LLMInterface) {
        self.llmInterface = llmInterface
    }
    
    public func extractText(from pdf: PDFDocument) async throws -> String {
        var extractedText = ""
        
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            if let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        if extractedText.isEmpty {
            throw DocumentProcessorError.noTextFound
        }
        
        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func extractText(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if let htmlString = String(data: data, encoding: .utf8) {
            // Basic HTML text extraction (remove tags)
            let cleanText = htmlString
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanText.isEmpty {
                throw DocumentProcessorError.noTextFound
            }
            
            return cleanText
        }
        
        throw DocumentProcessorError.unsupportedFormat
    }
    
    public func processDocument(pdf: PDFDocument) async throws -> ProcessedDocument {
        let content = try await extractText(from: pdf)
        let title = extractTitleFromContent(content) ?? "PDF Document"
        let summary = try await llmInterface.generateSummary(text: content)
        let flashcards = try await llmInterface.generateFlashcards(text: content)
        
        return ProcessedDocument(
            title: title,
            content: content,
            summary: summary,
            flashcards: flashcards,
            sourceType: .pdf
        )
    }
    
    public func processDocument(url: URL) async throws -> ProcessedDocument {
        let content = try await extractText(from: url)
        let title = url.lastPathComponent.isEmpty ? url.host ?? "Web Document" : url.lastPathComponent
        let summary = try await llmInterface.generateSummary(text: content)
        let flashcards = try await llmInterface.generateFlashcards(text: content)
        
        return ProcessedDocument(
            title: title,
            content: content,
            summary: summary,
            flashcards: flashcards,
            sourceType: .url
        )
    }
    
    public func processDocument(text: String) async throws -> ProcessedDocument {
        let title = extractTitleFromContent(text) ?? "Text Document"
        let summary = try await llmInterface.generateSummary(text: text)
        let flashcards = try await llmInterface.generateFlashcards(text: text)
        
        return ProcessedDocument(
            title: title,
            content: text,
            summary: summary,
            flashcards: flashcards,
            sourceType: .text
        )
    }
    
    private func extractTitleFromContent(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count > 5 && trimmed.count < 100 {
                return trimmed
            }
        }
        return nil
    }
}

public enum DocumentProcessorError: LocalizedError {
    case noTextFound
    case unsupportedFormat
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be extracted from the document."
        case .unsupportedFormat:
            return "The document format is not supported."
        case .processingFailed(let reason):
            return "Document processing failed: \(reason)"
        }
    }
} 