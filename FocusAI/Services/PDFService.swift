import Foundation
import PDFKit
import SwiftUI

enum PDFError: Error {
    case invalidPDF
    case extractionFailed
    case fileNotFound
}

class PDFService {
    static let shared = PDFService()
    private init() {}
    
    func extractText(from url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.invalidPDF
        }
        
        var text = ""
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            if let page = document.page(at: i) {
                if let pageText = page.string {
                    text += pageText + "\n"
                }
            }
        }
        
        guard !text.isEmpty else {
            throw PDFError.extractionFailed
        }
        
        return text
    }
    
    func createDocument(from url: URL) async throws -> Document {
        let content = try await extractText(from: url)
        return Document(
            title: url.lastPathComponent,
            content: content,
            source: .pdf(url)
        )
    }
    
    func previewPDF(url: URL) -> some View {
        PDFKitView(url: url)
    }
}

// SwiftUI wrapper for PDFView
private struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
} 