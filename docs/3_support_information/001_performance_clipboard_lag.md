# Support: Clipboard Lag & Performance

## 1. Symptom Description
*   **User Report:** "The app freezes for a second when I copy text." or "Pasting is laggy."
*   **Context:** usually happens when the clipboard history is full or contains large images.

## 2. Root Cause Analysis
*   **Old Behavior (Pre-v1.1):** The app was saving the entire history to disk *synchronously* on the main thread every time a copy occurred.
*   **New Behavior:** Processing and Saving are now asynchronous. If lag persists, it might be due to extreme memory usage or disk I/O bottlenecks (unlikely with new architecture).

## 3. Diagnosis Steps
1.  **Check Statistics:**
    *   Go to **Settings -> Storage & Limits**.
    *   Look at the "Current Usage Stats" section.
2.  **Interpret the Numbers:**
    *   **Total Items:** Should be under ~500 for optimal performance (Default limit: 100).
    *   **Images:** High image counts (e.g., > 50) consume significant memory.
    *   **Big Blobs:** This represents the size of the "Full Content" file. If this is > 50MB, load times might be slightly slower on startup (but shouldn't affect runtime).

## 4. Resolution
1.  **Immediate Fix:** Click **"Clear History"** in Settings.
2.  **Configuration Tweak:**
    *   Reduce "Max Text Items" (e.g., to 50).
    *   Reduce "Max Images" (e.g., to 10).
    *   Reduce "Full Limit (MB)" to prevent storing massive text files.
3.  **Verify Update:** Ensure the user is running the build with the `Async Architecture` (post-March 2026 update).

## 5. Performance Thresholds
*   **Safe Zone:** < 200 items, < 20MB blobs.
*   **Danger Zone:** > 1000 items, > 100MB blobs. (The app will handle it, but initial startup might be delayed).
