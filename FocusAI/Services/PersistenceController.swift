import CoreData
import os.log

class PersistenceController {
    static let shared = PersistenceController()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "Persistence")
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FocusAI")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                self.logger.error("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable persistent history tracking
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
    }
    
    // MARK: - Document Operations
    
    func createDocument(from document: Document) throws -> StoredDocument {
        let context = container.viewContext
        let storedDoc = StoredDocument(context: context)
        
        storedDoc.id = document.id
        storedDoc.content = document.content
        storedDoc.createdAt = Date()
        storedDoc.lastAccessed = Date()
        storedDoc.title = document.title ?? "Untitled Document"
        
        switch document.source {
        case .pdf(let url):
            storedDoc.sourceType = "pdf"
            storedDoc.sourcePath = url.path
        case .text(let text):
            storedDoc.sourceType = "text"
            storedDoc.content = text
        case .url(let url):
            storedDoc.sourceType = "url"
            storedDoc.sourcePath = url.absoluteString
        }
        
        try context.save()
        logger.info("Created document: \(storedDoc.id?.uuidString ?? "unknown")")
        return storedDoc
    }
    
    func updateDocument(_ storedDoc: StoredDocument, with document: Document) throws {
        let context = container.viewContext
        
        storedDoc.content = document.content
        storedDoc.lastAccessed = Date()
        
        try context.save()
        logger.info("Updated document: \(storedDoc.id?.uuidString ?? "unknown")")
    }
    
    func deleteDocument(_ document: StoredDocument) throws {
        let context = container.viewContext
        context.delete(document)
        try context.save()
        logger.info("Deleted document: \(document.id?.uuidString ?? "unknown")")
    }
    
    // MARK: - Summary Operations
    
    func saveSummary(_ content: String, for document: StoredDocument) throws {
        let context = container.viewContext
        
        // Delete existing summary if present
        if let existingSummary = document.summary {
            context.delete(existingSummary)
        }
        
        let summary = StoredSummary(context: context)
        summary.id = UUID()
        summary.content = content
        summary.createdAt = Date()
        summary.document = document
        
        try context.save()
        logger.info("Saved summary for document: \(document.id?.uuidString ?? "unknown")")
    }
    
    // MARK: - Flashcard Operations
    
    func saveFlashcards(_ cards: [(question: String, answer: String)], for document: StoredDocument) throws {
        let context = container.viewContext
        
        // Delete existing flashcards if present
        if let existingCards = document.flashcards as? Set<StoredFlashcard> {
            existingCards.forEach { context.delete($0) }
        }
        
        // Create new flashcards
        for (question, answer) in cards {
            let flashcard = StoredFlashcard(context: context)
            flashcard.id = UUID()
            flashcard.question = question
            flashcard.answer = answer
            flashcard.createdAt = Date()
            flashcard.document = document
        }
        
        try context.save()
        logger.info("Saved \(cards.count) flashcards for document: \(document.id?.uuidString ?? "unknown")")
    }
    
    // MARK: - Cleanup Operations
    
    func performCleanup() throws {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<StoredDocument> = StoredDocument.fetchRequest()
        
        // Find documents not accessed in the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        fetchRequest.predicate = NSPredicate(format: "lastAccessed < %@", thirtyDaysAgo as NSDate)
        
        let oldDocuments = try context.fetch(fetchRequest)
        for document in oldDocuments {
            context.delete(document)
            logger.info("Cleaned up old document: \(document.id?.uuidString ?? "unknown")")
        }
        
        try context.save()
    }
    
    // MARK: - Fetch Operations
    
    func fetchRecentDocuments(limit: Int = 10) throws -> [StoredDocument] {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<StoredDocument> = StoredDocument.fetchRequest()
        
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \StoredDocument.lastAccessed, ascending: false)
        ]
        fetchRequest.fetchLimit = limit
        
        return try context.fetch(fetchRequest)
    }
    
    func fetchDocument(withID id: UUID) throws -> StoredDocument? {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<StoredDocument> = StoredDocument.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        return try context.fetch(fetchRequest).first
    }
} 