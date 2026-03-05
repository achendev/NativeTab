# [002] Clipboard Manager Subsystem

## 1. Summary
The Clipboard Manager monitors the system pasteboard, maintains a history of items (text and images), handles persistence (encrypted), and provides a UI for retrieval. It is designed to handle large datasets without affecting the app's responsiveness.

## 2. Logic Flow

### A. Ingestion Loop (The "Tick")
1.  **Timer (Main Thread):** Checks `NSPasteboard.changeCount` every 0.5s.
2.  **Detection:** If changed, it reads the raw object.
3.  **Offload:** The raw object is sent to `processingQueue`.
    *   **Images:** Resized to 300x300 thumbnails (JPEG) and full blobs (PNG Base64).
    *   **Text:** Checked against size limits. If > Limit, it is truncated safely.
4.  **Re-Integration:** The processed `ClipboardItem` is sent back to **Main Thread**.
5.  **UI Update:** Item is inserted into `history` array.
6.  **Persistence:** A snapshot is sent to `saveQueue` for writing to disk.

### B. Storage Strategy (Split Model)
To keep the list UI fast, we split data into two layers:
1.  **History (Fast):** Contains metadata, thumbnails, and truncated text. This is loaded into memory for the List View.
2.  **Blobs (Slow):** Contains full-resolution images and full-text content. Stored in a separate dictionary `[UUID: String]`.

## 3. Key Classes & Responsibilities

| Class | Role |
| :--- | :--- |
| `ClipboardStore.swift` | The "Brain". Handles logic, storage, async queues, and encryption. |
| `ClipboardWindowManager` | Manages the floating window lifecycle (show/hide/focus). |
| `ClipboardHistoryView` | SwiftUI view. Handles search, filtering, and rendering. |
| `ClipboardWindow` | Custom `NSWindow` subclass to intercept local shortcuts (Esc). |

## 4. Gotchas & Edge Cases
*   **UTF-8 Slicing:** Never simply cut a string by bytes. Always check for validity.
*   **Image Bloat:** Storing raw `NSImage` TIFF data is huge. We convert thumbnails to JPEG and blobs to PNG Base64 to save space.
*   **Space Switching:** `ClipboardWindowManager` must handle `canJoinAllSpaces` correctly, or the window will force the user back to the Desktop where the app was launched.
