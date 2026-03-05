# Support: Activation Loop Issues

## 1. Symptom Description
*   **User Report:** "I press the hotkey in Terminal, but it goes back to FineTerm instead of Chrome."
*   **Behavior:** The app cycles FineTerm <-> Terminal, ignoring the previous app.

## 2. Root Cause Analysis
This is usually caused by **Window Server Lag**.
When the user presses the hotkey quickly after switching apps, the OS hasn't updated the "Active Application" registry yet. The app thinks the user is in a different state than they visually are.

## 3. Diagnosis Steps
1.  Enable **Debug Mode** in Settings.
2.  Open `Console.app` or tail the log: `tail -f ~/tmp/fineterm_debug.log`.
3.  Reproduce the loop.
4.  Look for lines starting with `DEBUG: Shortcut Pressed.`.
    *   **Bad Log:** `Visual Front: FineTerm` (when you are physically in Terminal).
    *   **Good Log:** `Visual Front: Terminal` (via Z-Order check).

## 4. Resolution
*   **Code Fix:** Ensure `getRealFrontmostApp()` is implemented (Fix applied 2026-03-05).
*   **Workaround:** Tell the user to wait 0.5s before pressing the hotkey (not ideal).
