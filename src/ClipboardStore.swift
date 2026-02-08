import SwiftUI
import Combine
import CryptoKit

class ClipboardStore: ObservableObject {
    @Published var history: [ClipboardItem] = []
    // Separate storage for large text blobs: [UUID: FullContent]
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
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            
            if let newString = NSPasteboard.general.string(forType: .string) {
                if !newString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    add(content: newString)
                }
            }
        }
    }
    
    func add(content: String) {
        // 1. Check duplication (Compare against full content if possible, or truncate match)
        // Optimization: Check latest item first
        if let first = history.first {
            // If the new content is massive, comparing strings might be slow, but essential for dedup.
            // Check if first item has a blob
            if let blobContent = blobs[first.id] {
                if blobContent == content { return }
            } else {
                if first.content == content { return }
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
            // It exceeds fast limit.
            // Create display version (Truncated)
            displayContent = truncate(string: content, limitBytes: fastLimitBytes)
            
            // Check against Slow Limit
            if content.utf8.count <= slowLimitBytes {
                fullContent = content
            } else {
                // Exceeds even the slow limit, truncate full content to max slow limit
                fullContent = truncate(string: content, limitBytes: slowLimitBytes)
            }
        }
        
        // 4. Store
        let item = ClipboardItem(content: displayContent, timestamp: Date())
        
        // Insert Fast Item
        history.insert(item, at: 0)
        
        // Insert Blob if exists
        if let blob = fullContent {
            blobs[item.id] = blob
        }
        
        // 5. Pruning (History Count)
        let limit = UserDefaults.standard.integer(forKey: AppConfig.Keys.clipboardHistorySize)
        let effectiveLimit = limit > 0 ? limit : 100
        
        if history.count > effectiveLimit {
            let removedItems = history.suffix(from: effectiveLimit)
            // Cleanup blobs for removed items
            for removed in removedItems {
                blobs.removeValue(forKey: removed.id)
            }
            history = Array(history.prefix(effectiveLimit))
        }
        
        save()
    }
    
    private func truncate(string: String, limitBytes: Int) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        if data.count <= limitBytes { return string }
        
        let truncatedData = data.prefix(limitBytes)
        if let safeString = String(data: truncatedData, encoding: .utf8) {
            return safeString
        }
        
        // Back off to find valid UTF8
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
        
        // Check if we have a larger "Blob" version
        let contentToPaste = blobs[item.id] ?? item.content
        pb.setString(contentToPaste, forType: .string)
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
                // It's okay if this fails, we just lose the "Full" versions, functionality remains
            }
        }
    }
}