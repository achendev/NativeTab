# [001] Tahoe Compatibility: Interception & Snapping

**Status:** Partially Fixed
**Last Updated:** 2026-02-13

## 1. Problem & Context
macOS 16 "Tahoe" introduced changes to window metrics and coordinate reporting that broke two key features:
1.  **Interception:** Hit-testing via calculated geometry (`CGRectContainsPoint`) became unreliable. Mouse events over the Terminal were not being detected or were being detected incorrectly due to mismatched coordinate spaces.
2.  **Snapping (Window Overlap):** `CGWindowList` behavior changed regarding window shadows.
    *   **Sequoia (<16.0):** Bounds *included* the window shadow (~40px padding).
    *   **Tahoe (>=16.0):** Bounds match the *visual content* (tight bounds, 0px shadow).
    *   **Result:** Using a fixed gap causes the FineTerm window to overlap the Terminal window in Tahoe (too close) or leaves a huge gap in Sequoia.

## 2. Solutions Status

### A. Interception: ✅ SOLVED
**The Fix:** System-Level Hit-Testing (AX API).

Instead of manually calculating if `Event.Location` is inside `Window.Rect`, we now ask the Window Server directly via the Accessibility API.

**Implementation Details:**
*   We use `AXUIElementCopyElementAtPosition` to query the element under the mouse cursor.
*   We check if the returned element's Owner PID matches the running Terminal instance.
*   **Why this works:** This bypasses all coordinate space mismatches, rounded corner issues, and invisible border problems. If the OS thinks the mouse is over the window, we intercept.

### B. Snapping: ❌ NOT SOLVED (Pending)
**Current State:**
The snapping logic currently relies on `CGWindowList` geometry. 
*   In **Sequoia**, the "Frame" includes invisible shadow padding, so snapping to `Frame.MaxX + 1` naturally creates a visual gap.
*   In **Tahoe**, the "Frame" is tight to the glass. Snapping to `Frame.MaxX + 1` places FineTerm immediately adjacent to the glass, causing the window shadows to draw *on top* of the Terminal content, or looking visually cramped.

**Proposed Solution (Not Implemented):**
We need "Adaptive Shadow Detection". We should compare the **Physical Width** (CG) vs **Visual Width** (AX).
*   If `CG > AX + 15px` -> Assume Shadow Padding -> Use small gap.
*   If `CG ≈ AX` -> Assume Tight Bounds -> Use larger gap (12px).

## 3. Revision History
*   **2026-02-13:** Interception logic fixed using `AXUIElementCopyElementAtPosition`. Snapping issue identified but implementation deferred.