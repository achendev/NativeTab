# NativeTab

**The missing Connection Manager and Input Enhancer for macOS Terminal.**

NativeTab is a lightweight, native Swift application designed to supercharge the stock macOS Terminal.app. It bridges the gap between the native terminal experience and the advanced session management features found in heavy third-party emulators like iTerm2 or SecureCRT.

It does not replace Terminal.app—it **wraps** it with a powerful session manager and injects "Pro" input behaviors that Unix and Windows admins have missed for years.

## 🚀 Why is this "New & Fresh"?

Most terminal replacements (Hyper, Alacritty, iTerm) require you to abandon the highly optimized, battery-friendly native macOS Terminal. 

**NativeTab is different:**
1.  **Native Performance:** You still use the actual Terminal.app. We just automate it.
2.  **Unix/Windows Mouse Behavior:** Finally brings **"Copy on Select"** (PuTTY/Linux style) and **"Paste on Right Click"** to the native Mac Terminal.
3.  **Focus Flow:** A seamless Global Hotkey system allows you to toggle between your connection list and your active terminal instantly.
4.  **Zero Bloat:** Written in pure Swift. No Electron, no Python, no heavy dependencies. 5MB memory footprint.

---

## ✨ Key Features

### 1. Connection Manager
*   **Organized:** Group your SSH, Telnet, or local script commands into foldable folders.
*   **Searchable:** Instant "Spotlight-style" search for server names or commands.
*   **Drag & Drop:** Reorder connections and organize groups intuitively.
*   **Import/Export:** Share your server lists via JSON.

### 2. "Pro" Input Interceptors
*   **Copy on Select:** Simply dragging your mouse over text in the Terminal automatically copies it to the clipboard. No more `Cmd+C`.
*   **Paste on Right Click:** Right-clicking anywhere in the Terminal window pastes your clipboard.
*   *Note: These features operate by intercepting mouse events specifically when Terminal is focused and injecting keystrokes.*

### 3. The "Focus Loop"
*   **Global Hotkey (Default: `Cmd+N`):** 
    *   When you are in the Terminal and need to open a new server, press `Cmd+N`.
    *   The Wrapper intercepts this (preventing a new window) and instantly brings the Connection List to the front.
    *   Select your server, hit Enter, and it launches a new tab in your existing Terminal window.

---

## 🛠 Installation & Build

This project is a raw Swift codebase. You don't need Xcode to build it, just the command line tools.

1.  **Build the App:**
    ```bash
    chmod +x build.sh
    ./build.sh
    ```
    This creates the executable at `./bin/NativeTab`.

2.  **Run:**
    ```bash
    ./bin/NativeTab
    ```

3.  **⚠️ CRITICAL: Accessibility Permissions**
    Because this app intercepts global keystrokes (to detect `Cmd+N` in Terminal) and mouse events (for Copy/Paste), macOS requires **Accessibility Access**.
    
    1.  On first launch, the app will check for permissions.
    2.  Go to **System Settings -> Privacy & Security -> Accessibility**.
    3.  If `NativeTab` is in the list, enable the toggle.
    4.  If not, drag the `./bin/NativeTab` file into the list manually.
    5.  **Restart the app.**

---

## 📖 Usage Guide

### Managing Connections
*   **Add:** Click the "+" button or fill in the form at the bottom.
*   **Edit:** Click a row to load it into the editor.
*   **Connect:** Click the "Play" icon or press `Enter` on a highlighted row.
*   **Search:** Just start typing. The list filters automatically. Use `Up`/`Down` arrows to navigate and `Enter` to connect.

### Keyboard Shortcuts
| Context | Shortcut | Action |
| :--- | :--- | :--- |
| **Terminal** | `Cmd + N` | Switch focus to NativeTab (Configurable) |
| **Wrapper** | `Up / Down` | Navigate connection list |
| **Wrapper** | `Enter` | Connect to selected server |

### Settings
Click the ⚙️ icon to configure:
*   **Wrappers:** automatically add commands before (e.g., `unset HISTFILE;`) or after your connection command.
*   **Mouse Behavior:** Toggle Copy-on-Select or Paste-on-Right-Click.
*   **Hotkeys:** Change the global wake shortcut.

---

## 🔧 How It Works (Architecture)

1.  **SwiftUI Interface:** Renders the lightweight list and settings.
2.  **AppleScript Bridge:** When you click "Connect", the app talks to Terminal.app via AppleScript to spawn tabs and type commands.
3.  **CGEventTap (Interceptors):** Low-level CoreGraphics APIs hook into the system event stream.
    *   The app filters for events only when `com.apple.Terminal` is the frontmost application.
    *   It swallows specific events (like Right Click) and injects simulated keystrokes (`Cmd+V`) in their place.

## 📝 License
MIT License. Hack away!
