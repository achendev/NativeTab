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
        
        // CRITICAL: .canJoinAllSpaces allows the window to appear on the current desktop 
        // without forcing a switch to the Main Window's desktop.
        // .fullScreenAuxiliary allows it to appear over full screen apps.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
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
            }
        }
        
        // 1. Prepare Window on Current Space
        // We do NOT call NSApp.unhide(nil) here, as that forces the Main Window (on another space) 
        // to become relevant to the Window Server, often triggering a space switch.
        
        window.center()
        
        // Ordering the window front behaves like a 'local' action on the current space
        // because of .canJoinAllSpaces.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // 2. Activate App
        // Now that we have a visible window on the CURRENT space, activating the app 
        // should focus this window in place, rather than switching to the Main Window's space.
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        guard window.isVisible else { return }
        
        window.orderOut(nil)
        
        // Logic to return focus
        if let prev = previousApp, !prev.isTerminated {
            prev.activate(options: [])
            previousApp = nil
        } else {
            // Check if Main Window (Session Manager) is visible
            let hasVisibleMainWindow = NSApp.windows.contains { $0 !== window && $0.isVisible && !$0.isMiniaturized }
            
            // If the Session Manager is closed, hide the app to behave like a background utility.
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
