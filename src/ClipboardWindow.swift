import Cocoa

class ClipboardWindow: NSWindow {
    // Callback to trigger when Esc is pressed
    var onEsc: (() -> Void)?
    private var localMonitor: Any?

    // Custom Init to attach the monitor immediately
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Intercept Esc (53) locally for this window
        // This works even if a specific SwiftUI view inside doesn't have focus
        self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isKeyWindow else { return event }
            
            if event.keyCode == 53 { // Esc
                self.onEsc?()
                return nil // Swallow event
            }
            return event
        }
    }
    
    // Deinit isn't reliably called for windows kept in memory, 
    // but useful if we ever destroy it.
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }
}
