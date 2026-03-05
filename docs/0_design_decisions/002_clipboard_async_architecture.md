# [002] Clipboard Async Architecture & Snapshotting

**Status:** Implemented
**Last Updated:** 2026-03-05

## 1. Problem & Context
The Clipboard Manager was originally designed with a synchronous flow: `Detect Change -> Process Data -> Update UI -> Save to Disk`.
As the history grew (especially with images and large text blobs), the `Save to Disk` step—which involves JSON encoding and AES-GCM encryption—began blocking the Main Thread.
*   **Symptom:** Users experienced UI freezes or "lag" immediately after copying text, or when switching spaces, as the app struggled to serialize the large history file synchronously.

## 2. The Solution
We moved to a **Dual-Queue Async Architecture** with **State Snapshotting**.

### A. Threading Model
1.  **Main Thread:** Handles lightweight polling (`NSPasteboard.changeCount`) and UI updates.
2.  **Processing Queue (`userInitiated`):** Handles heavy input processing (Image resizing/compression, Text truncation) *before* the item enters the history.
3.  **Save Queue (`utility`):** Handles serialization, encryption, and file I/O *after* the item is added.

### B. State Snapshotting (Copy-on-Write)
To solve thread safety without blocking the UI with locks:
*   When `save()` is called, we capture a local copy (snapshot) of the `history` array and `blobs` dictionary on the **Main Thread**.
*   Swift's `Copy-on-Write` behavior ensures this is an O(1) operation unless the data is modified immediately after.
*   This immutable snapshot is passed to the background `saveQueue`.
*   **Result:** The UI remains responsive immediately, while the disk write happens milliseconds later in the background.

## 3. Data Integrity: UTF-8 Truncation
We implemented a strict "Backtracking" logic for text truncation.
*   **Naive Approach:** `string.prefix(1000)` counts characters, not bytes. This allows 1000 emojis (4KB) to pass a 1KB limit.
*   **Byte Approach:** Cutting `data.prefix(1000)` might slice a multi-byte character in half, resulting in invalid UTF-8.
*   **Our Logic:** We cut at the byte limit, then backtrack up to 3 bytes to find a valid character boundary. This ensures the stored data is *always* valid UTF-8 and strictly adheres to the storage quota.

## 4. Why this approach?
*   **Pros:** Zero UI blocking, thread-safe without complex locks, reliable data integrity.
*   **Cons:** Small complexity increase in `ClipboardStore`.

## 5. Revision History
*   **2026-03-05:** Refactored from synchronous to async architecture to fix lag issues. Added stats visibility.