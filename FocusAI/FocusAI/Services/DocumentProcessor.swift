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
            // Extract metadata first
            var metadata = extractMetadata(from: htmlString)
            
            // Basic HTML text extraction (remove tags)
            let cleanText = htmlString
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanText.isEmpty {
                throw DocumentProcessorError.noTextFound
            }
            
            // Combine metadata with content
            var fullText = ""
            if !metadata.isEmpty {
                fullText += "Article Metadata:\n" + metadata + "\n\nArticle Content:\n"
            }
            fullText += cleanText
            
            return fullText
        }
        
        throw DocumentProcessorError.unsupportedFormat
    }
    
    private func extractMetadata(from html: String) -> String {
        var metadata: [String] = []
        
        // Extract author from meta tags
        if let author = extractMetaContent(from: html, name: "author") {
            metadata.append("Author: \(author)")
        }
        
        // Extract publication date from meta tags
        if let date = extractMetaContent(from: html, name: "date") ??
                      extractMetaContent(from: html, property: "article:published_time") ??
                      extractMetaContent(from: html, property: "article:published") {
            metadata.append("Published: \(date)")
        }
        
        // Extract title from meta tags
        if let title = extractMetaContent(from: html, property: "og:title") ??
                       extractMetaContent(from: html, name: "title") {
            metadata.append("Title: \(title)")
        }
        
        // Extract description
        if let description = extractMetaContent(from: html, name: "description") ??
                            extractMetaContent(from: html, property: "og:description") {
            metadata.append("Description: \(description)")
        }
        
        return metadata.joined(separator: "\n")
    }
    
    private func extractMetaContent(from html: String, name: String? = nil, property: String? = nil) -> String? {
        let namePattern = name != nil ? "name=\"\(name!)\"" : ""
        let propertyPattern = property != nil ? "property=\"\(property!)\"" : ""
        let searchPattern = name != nil ? namePattern : propertyPattern
        
        let pattern = "<meta[^>]*\(searchPattern)[^>]*content=\"([^\"]+)\"[^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let range = Range(match.range(at: 1), in: html)
                if let range = range {
                    return String(html[range])
                }
            }
        } catch {
            // Ignore regex errors
        }
        
        return nil
    }
    
    public func processDocument(pdf: PDFDocument) async throws -> ProcessedDocument {
        let content = try await extractText(from: pdf)
        let title = extractTitleFromContent(content) ?? "PDF Document"
        let summary = try await llmInterface.generateSummary(text: content)
        let flashcards = try await llmInterface.generateFlashcards(text: content, count: 5)
        
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
        let flashcards = try await llmInterface.generateFlashcards(text: content, count: 5)
        
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
        let flashcards = try await llmInterface.generateFlashcards(text: text, count: 5)
        
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