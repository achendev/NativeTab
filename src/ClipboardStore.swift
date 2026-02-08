import SwiftUI
import Combine
import CryptoKit
import Cocoa

class ClipboardStore: ObservableObject {
    @Published var history: [ClipboardItem] = []
    // Separate storage for large text blobs AND full images: [UUID: Base64String]
    private var blobs: [UUID: String] = [:]
    
    private let fileURL: URL
    private let blobsURL: URL
    
    private var timer: Timer?
    private var lastChangeCount: Int
    
    // Key for storing the encryption key in UserDefaults
    private let keyStorageName = "FineTermClipboardKey"
    
    init() {
        let fileManager = FileManager.default
        
        // Target: ~/Library/Application Support/<BundleID>/
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.local.FineTerm"
        let appDir = appSupport.appendingPathComponent(bundleID)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        
        fileURL = appDir.appendingPathComponent("clipboard_history.enc")
        blobsURL = appDir.appendingPathComponent("clipboard_blobs.enc")
        
        lastChangeCount = NSPasteboard.general.changeCount
        
        load()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            
            // Priority: Check for Image first, then Text
            // This prevents "text" version of image (e.g. file path or URL) taking precedence if user explicitly copied image
            if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                add(image: image)
            } else if let newString = pb.string(forType: .string) {
                if !newString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    add(content: newString)
                }
            }
        }
    }
    
    // MARK: - Image Handling
    
    func add(image: NSImage) {
        // 1. Generate ID and Timestamp
        let id = UUID()
        let now = Date()
        
        // 2. Prepare Thumbnail
        // Resize to max 600x600 for list view (High Quality / Retina)
        // Previous 100x100 was causing blur on new large preview layout
        let thumbSize = NSSize(width: 300, height: 300)
        let thumbnail = resize(image: image, to: thumbSize)
        
        // Optimize: Convert to JPEG (0.7) to keep file size small despite larger resolution
        var thumbData = thumbnail.tiffRepresentation
        if let tiff = thumbData, let bitmap = NSBitmapImageRep(data: tiff) {
            if let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                thumbData = jpeg
            }
        }
        
        // 3. Prepare Description
        let sizeDesc = "Image \(Int(image.size.width))x\(Int(image.size.height))"
        
        // 4. Create Item
        let item = ClipboardItem(
            id: id,
            content: sizeDesc,
            timestamp: now,
            type: .image,
            thumbnailData: thumbData
        )
        
        // 5. Store Full Image in Blobs (Base64 encoded PNG)
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            blobs[id] = pngData.base64EncodedString()
        }
        
        // 6. Insert
        history.insert(item, at: 0)
        
        // 7. Prune
        pruneHistory()
        
        save()
    }
    
    private func resize(image: NSImage, to maxSize: NSSize) -> NSImage {
        if image.size.width == 0 || image.size.height == 0 { return image }
        
        let widthRatio = maxSize.width / image.size.width
        let heightRatio = maxSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)
        
        // Don't upscale if image is smaller than thumbnail box (prevents pixelation)
        let finalRatio = min(ratio, 1.0)
        
        let newSize = NSSize(width: image.size.width * finalRatio, height: image.size.height * finalRatio)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    // MARK: - Text Handling
    
    func add(content: String) {
        // 1. Check duplication
        if let first = history.first {
            // Check text duplication
            if first.type == .text {
                if let blobContent = blobs[first.id] {
                    if blobContent == content { return }
                } else {
                    if first.content == content { return }
                }
            }
        }
        
        // 2. Limits Configuration
        let fastLimitKB = max(1, UserDefaults.standard.integer(forKey: AppConfig.Keys.clipboardItemSizeLimitKB))
        let fastLimitBytes = fastLimitKB * 1024
        
        let slowLimitMB = max(1, UserDefaults.standard.integer(forKey: AppConfig.Keys.clipboardLargeItemSizeLimitMB))
        let slowLimitBytes = slowLimitMB * 1024 * 1024
        
        var displayContent = content
        var fullContent: String? = nil
        
        // 3. Size Logic
        if content.utf8.count > fastLimitBytes {
            displayContent = truncate(string: content, limitBytes: fastLimitBytes)
            
            if content.utf8.count <= slowLimitBytes {
                fullContent = content
            } else {
                fullContent = truncate(string: content, limitBytes: slowLimitBytes)
            }
        }
        
        // 4. Store
        let item = ClipboardItem(content: displayContent, timestamp: Date())
        history.insert(item, at: 0)
        
        if let blob = fullContent {
            blobs[item.id] = blob
        }
        
        // 5. Prune
        pruneHistory()
        
        save()
    }
    
    // MARK: - Pruning Logic
    
    private func pruneHistory() {
        let globalLimit = UserDefaults.standard.integer(forKey: AppConfig.Keys.clipboardHistorySize)
        let effectiveGlobalLimit = globalLimit > 0 ? globalLimit : 100
        
        let imageLimit = UserDefaults.standard.integer(forKey: AppConfig.Keys.clipboardMaxImages)
        let effectiveImageLimit = imageLimit > 0 ? imageLimit : 50
        
        // 1. Enforce Image Count Limit (Sub-limit)
        let currentImages = history.filter { $0.type == .image }
        if currentImages.count > effectiveImageLimit {
            // Remove oldest images until fit
            // We need to remove them from main history
            let imagesToRemoveCount = currentImages.count - effectiveImageLimit
            // The ones at the end of the filtered list are the oldest
            let imagesToRemove = currentImages.suffix(imagesToRemoveCount)
            let idsToRemove = Set(imagesToRemove.map { $0.id })
            
            history.removeAll { idsToRemove.contains($0.id) }
            for id in idsToRemove { blobs.removeValue(forKey: id) }
        }
        
        // 2. Enforce Global Limit (Total Items)
        if history.count > effectiveGlobalLimit {
            let removedItems = history.suffix(from: effectiveGlobalLimit)
            for removed in removedItems {
                blobs.removeValue(forKey: removed.id)
            }
            history = Array(history.prefix(effectiveGlobalLimit))
        }
    }
    
    private func truncate(string: String, limitBytes: Int) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        if data.count <= limitBytes { return string }
        
        let truncatedData = data.prefix(limitBytes)
        if let safeString = String(data: truncatedData, encoding: .utf8) {
            return safeString
        }
        
        for i in 1...3 {
            if limitBytes - i > 0 {
                let smaller = data.prefix(limitBytes - i)
                if let safeString = String(data: smaller, encoding: .utf8) {
                    return safeString
                }
            }
        }
        return String(string.prefix(limitBytes))
    }
    
    func delete(id: UUID) {
        history.removeAll { $0.id == id }
        blobs.removeValue(forKey: id)
        save()
    }
    
    func copyToClipboard(item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        if item.type == .image {
            // Retrieve blob, decode base64, write to pasteboard
            if let base64 = blobs[item.id],
               let data = Data(base64Encoded: base64),
               let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        } else {
            let contentToPaste = blobs[item.id] ?? item.content
            pb.setString(contentToPaste, forType: .string)
        }
    }
    
    func clear() {
        history.removeAll()
        blobs.removeAll()
        save()
    }
    
    /// Helper for Search: Returns full content if available, else fast content
    func getFullContent(for item: ClipboardItem) -> String {
        return blobs[item.id] ?? item.content
    }
    
    // MARK: - Encryption & Persistence
    
    private func getEncryptionKey() -> SymmetricKey {
        let defaults = UserDefaults.standard
        if let keyString = defaults.string(forKey: keyStorageName),
           let keyData = Data(base64Encoded: keyString) {
            return SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            defaults.set(keyData.base64EncodedString(), forKey: keyStorageName)
            return key
        }
    }

    private func save() {
        do {
            let key = getEncryptionKey()
            
            // 1. Save History (Fast)
            let historyData = try JSONEncoder().encode(history)
            let historyBox = try AES.GCM.seal(historyData, using: key)
            if let combined = historyBox.combined {
                try combined.write(to: fileURL)
            }
            
            // 2. Save Blobs (Slow)
            if !blobs.isEmpty {
                let blobsData = try JSONEncoder().encode(blobs)
                let blobsBox = try AES.GCM.seal(blobsData, using: key)
                if let combined = blobsBox.combined {
                    try combined.write(to: blobsURL)
                }
            } else {
                // If empty, delete file to keep clean
                try? FileManager.default.removeItem(at: blobsURL)
            }
            
        } catch {
            print("Clipboard Save Error: \(error)")
        }
    }
    
    private func load() {
        let key = getEncryptionKey()
        let decoder = JSONDecoder()
        
        // 1. Load History
        if let encryptedData = try? Data(contentsOf: fileURL) {
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                self.history = try decoder.decode([ClipboardItem].self, from: decryptedData)
            } catch {
                print("Clipboard History Load Error: \(error)")
            }
        }
        
        // 2. Load Blobs
        if let encryptedBlobs = try? Data(contentsOf: blobsURL) {
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedBlobs)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                self.blobs = try decoder.decode([UUID: String].self, from: decryptedData)
            } catch {
                print("Clipboard Blobs Load Error: \(error)")
            }
        }
    }
}