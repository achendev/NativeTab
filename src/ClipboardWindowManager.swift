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
        window.hidesOnDeactivate = true
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
            if currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp = currentApp
            } else {
                previousApp = nil
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    func close() {
        guard window.isVisible else { return }
        
        window.orderOut(nil)
        
        // Logic to return focus
        if let prev = previousApp {
            prev.activate(options: [])
            previousApp = nil
        } else {
            // Fallback: If no specific previous app, ensure we don't block workflow.
            // Check main app window status via AppDelegate if possible, or just hide app if main window is not key.
            // Ideally, we shouldn't couple strictly to AppDelegate here, but we can check NSApp.windows.
            // Simple logic: if Main Window is visible, let it be. If not, hide app.
            
            // Find main window by title or exclude clipboard window
            let hasVisibleMainWindow = NSApp.windows.contains { $0 !== window && $0.isVisible && !$0.isMiniaturized }
            
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
            DispatchQueue.main.async {
                if self.window.isVisible {
                    self.close()
                }
            }
        }
    }
}
