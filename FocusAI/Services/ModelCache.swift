import Foundation
import os.log

/// Manages caching and loading of ML models
actor ModelCache {
    static let shared = ModelCache()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.focusai", category: "ModelCache")
    
    private let fileManager = FileManager.default
    private var modelLoadProgress: Progress?
    
    enum CacheError: LocalizedError {
        case modelNotFound
        case cacheFailed(String)
        case invalidCache
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Model file not found in bundle"
            case .cacheFailed(let reason):
                return "Failed to cache model: \(reason)"
            case .invalidCache:
                return "Cached model is invalid or corrupted"
            }
        }
    }
    
    private init() {}
    
    /// Returns the URL for the cached model, copying from bundle if necessary
    func getCachedModelURL() async throws -> URL {
        let cacheDir = try getCacheDirectory()
        let cachedModelURL = cacheDir.appendingPathComponent(ModelConfig.modelName)
        
        // Check if cached model exists and is valid
        if await isCachedModelValid(at: cachedModelURL) {
            logger.info("Using cached model at \(cachedModelURL.path)")
            return cachedModelURL
        }
        
        // Copy model from bundle to cache
        return try await cacheModelFromBundle(to: cachedModelURL)
    }
    
    /// Validates the cached model file
    private func isCachedModelValid(at url: URL) async -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let modificationDate = attributes[.modificationDate] as? Date,
                  let fileSize = attributes[.size] as? UInt64 else {
                return false
            }
            
            // Check if cache is recent (less than 7 days old)
            let cacheAge = Date().timeIntervalSince(modificationDate)
            let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
            
            // Verify file size is reasonable (> 100MB for quantized model)
            let minModelSize: UInt64 = 100 * 1024 * 1024 // 100MB
            
            return cacheAge < maxCacheAge && fileSize > minModelSize
        } catch {
            logger.error("Failed to validate cached model: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Copies the model from bundle to cache directory
    private func cacheModelFromBundle(to destination: URL) async throws -> URL {
        guard let bundleModelURL = Bundle.main.url(forResource: ModelConfig.modelName, withExtension: nil) else {
            throw CacheError.modelNotFound
        }
        
        // Create a progress object for tracking
        let progress = Progress(totalUnitCount: 1)
        self.modelLoadProgress = progress
        
        do {
            // Remove any existing cached model
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            
            // Copy model file
            try fileManager.copyItem(at: bundleModelURL, to: destination)
            progress.completedUnitCount = 1
            
            logger.info("Successfully cached model to \(destination.path)")
            return destination
        } catch {
            progress.cancel()
            throw CacheError.cacheFailed(error.localizedDescription)
        }
    }
    
    /// Returns the cache directory URL, creating it if necessary
    private func getCacheDirectory() throws -> URL {
        let cacheDir = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("MLModels", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return cacheDir
    }
    
    /// Cleans up old cached models
    func cleanCache() async throws {
        let cacheDir = try getCacheDirectory()
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        for url in contents {
            if !await isCachedModelValid(at: url) {
                try fileManager.removeItem(at: url)
                logger.info("Removed invalid cached model at \(url.path)")
            }
        }
    }
    
    /// Returns the current model loading progress
    var currentProgress: Progress? {
        modelLoadProgress
    }
} 