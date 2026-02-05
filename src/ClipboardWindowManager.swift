import Cocoa
import SwiftUI

class ClipboardWindowManager: NSObject, NSWindowDelegate {
    private var window: ClipboardWindow!
    private var store: ClipboardStore
    private var previousApp: NSRunningApplication?
    
    init(store: ClipboardStore) {
        self.store = store
        super.init()
        setupWindow()
    }
    
    private func setupWindow() {
        window = ClipboardWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Clipboard History"
        window.level = .floating
        // REMOVED: window.hidesOnDeactivate = true
        // This caused the window to get stuck in a hidden state when the app was hidden manually.
        
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Setup Close/Esc Callback
        window.onEsc = { [weak self] in
            self?.close()
        }
        
        let contentView = ClipboardHistoryView(store: store) { [weak self] in
            self?.close()
        }
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    func toggle() {
        if window.isVisible {
            close()
        } else {
            show()
        }
    }
    
    func show() {
        // Capture previous app to restore focus later
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            // Don't capture self as previous app
            if currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp = currentApp
            }
        }
        
        // 1. Ensure the application is technically visible (unhidden)
        // This is crucial if close() previously called NSApp.hide() because the main window was closed.
        NSApp.unhide(nil)
        
        // 2. Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // 3. Show and focus the window
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless() // Force to front
    }
    
    func close() {
        guard window.isVisible else { return }
        
        window.orderOut(nil)
        
        // Logic to return focus
        if let prev = previousApp, !prev.isTerminated {
            prev.activate(options: [])
            previousApp = nil
        } else {
            // Fallback: If no specific previous app, ensure we don't block workflow.
            
            // Check if Main Window (Session Manager) is visible
            let hasVisibleMainWindow = NSApp.windows.contains { $0 !== window && $0.isVisible && !$0.isMiniaturized }
            
            // If the Session Manager is closed, we should hide the app entirely
            // so it behaves like a background utility when the clipboard closes.
            if !hasVisibleMainWindow {
                NSApp.hide(nil)
            }
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window {
            close()
            return false 
        }
        return true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win === window {
            // Use a small delay to ensure we aren't just switching focus internally
            DispatchQueue.main.async {
                if self.window.isVisible {
                    self.close()
                }
            }
        }
    }
}
