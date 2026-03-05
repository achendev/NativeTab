# [003] Activation Loop Robustness & Z-Order Fallback

**Status:** Implemented
**Last Updated:** 2026-03-05

## 1. Problem & Context
The "Focus Loop" feature allows a user to cycle: **Origin App (e.g. Chrome) -> FineTerm -> Terminal -> Origin App**.

**The Bug:**
When switching from **FineTerm** to **Terminal** (Step 2), macOS takes ~100-300ms to update `NSWorkspace.shared.frontmostApplication`.
1.  User presses shortcut in FineTerm.
2.  App activates Terminal.
3.  User presses shortcut in Terminal immediately.
4.  **Issue:** `NSWorkspace` still reports `FineTerm` as the active app because the OS animation hasn't finished updating the registry.
5.  **Result:** The code thinks we are still in FineTerm (or transitioning), fails to detect "Terminal is Front", and erroneously triggers Step 1 (Origin -> FineTerm), causing an infinite loop between FineTerm and Terminal, losing the original app reference.

## 2. The Solution: Z-Order Truth
We cannot trust `NSWorkspace` during rapid window switching. We implemented a **Hybrid Detection Strategy** in `getRealFrontmostApp()`:

1.  **Self-Truth:** Check `NSRunningApplication.current.isActive`. This is the absolute truth for "Is FineTerm active?".
2.  **Staleness Check:** If `NSWorkspace` says FineTerm is active, but `Self-Truth` says we are NOT, then `NSWorkspace` is stale (lagging).
3.  **Z-Order Fallback:** In stale cases, we query `CGWindowListCopyWindowInfo` to find the physical top-most window on layer 0. This bypasses high-level workspace abstraction and looks at what the Window Server is actually rendering on top.

## 3. Why this approach?
*   **Pros:** Solves the race condition definitively. `CGWindowList` reflects the visual reality faster than `NSWorkspace` notifications propagate.
*   **Cons:** Slightly more expensive CPU operation than a property access, but negligible since it only runs on specific keystrokes.

## 4. Revision History
*   **2026-03-05:** Introduced `getRealFrontmostApp` to fix the "Third Activation" bug where the loop would reset.