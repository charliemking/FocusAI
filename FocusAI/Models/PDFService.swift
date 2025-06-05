import Foundation
import PDFKit
import SwiftUI

class PDFService {
    static let shared = PDFService()
    
    private init() {}
    
    func previewPDF(url: URL) -> PDFDocument? {
        return PDFDocument(url: url)
    }
    
    func createDocument(from url: URL) async throws -> Document {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.pdfExtractionFailed
        }
        
        var text = ""
        if let pageCount = pdfDocument.pageCount {
            for i in 0..<pageCount {
                if let page = pdfDocument.page(at: i) {
                    if let pageText = page.string {
                        text += pageText + "\n"
                    }
                }
            }
        }
        
        if text.isEmpty {
            throw DocumentError.pdfExtractionFailed
        }
        
        return Document(
            source: .pdf(url),
            title: url.deletingPathExtension().lastPathComponent
        )
    }
}

enum DocumentError: Error {
    case pdfExtractionFailed
    case urlContentFailed
    case invalidURL
    case persistenceError(String)
    case sharingError(String)
} 