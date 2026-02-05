import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var mouseInterceptor: MouseInterceptor?
    var keyboardInterceptor: KeyboardInterceptor?
    
    // Clipboard Manager Components
    var clipboardStore: ClipboardStore!
    var clipboardWindow: ClipboardWindow! 
    
    // Focus Management
    var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register Defaults
        UserDefaults.standard.register(defaults: [
            "copyOnSelect": true,
            "pasteOnRightClick": true,
            "debugMode": false,
            "commandPrefix": "unset HISTFILE ; clear ; ",
            "commandSuffix": " && exit",
            "hideCommandInList": true,
            "smartFilter": true,
            "changeTerminalName": true,
            "globalShortcutKey": "n",
            "globalShortcutModifier": "command",
            "globalShortcutAnywhere": false,
            "secondActivationToTerminal": true,
            "escToTerminal": false,
            "enableClipboardManager": false,
            "clipboardShortcutKey": "u",
            "clipboardShortcutModifier": "command"
        ])

        setupMainMenu()
        
        NSApp.setActivationPolicy(.regular)
        
        // --- Main Connection Window ---
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "FineTerm"
        
        // --- Clipboard Setup ---
        setupClipboardManager()
        
        checkPermissionsAndStart()
    }

    func checkPermissionsAndStart() {
        if PermissionManager.checkAccessibility() {
            startMainApp()
        } else {
            showPermissionOverlay()
        }
    }

    func showPermissionOverlay() {
        let permissionView = PermissionView { [weak self] in
            self?.startMainApp()
        }
        window.contentView = NSHostingView(rootView: permissionView)
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 320))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func startMainApp() {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 320, height: 500))
        window.center()
        
        let contentView = ConnectionListView()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        mouseInterceptor = MouseInterceptor()
        mouseInterceptor?.start()
        
        keyboardInterceptor = KeyboardInterceptor()
        keyboardInterceptor?.start()
        
        clipboardStore.startMonitoring()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("FineTerm Started")
    }
    
    // MARK: - Clipboard Logic
    
    func setupClipboardManager() {
        clipboardStore = ClipboardStore()
        
        // Use custom subclass (NSWindow) with standard style mask
        clipboardWindow = ClipboardWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        clipboardWindow.title = "Clipboard History"
        // .floating keeps it above the Main Window, visually separating them
        clipboardWindow.level = .floating 
        clipboardWindow.hidesOnDeactivate = true 
        clipboardWindow.isReleasedWhenClosed = false
        
        clipboardWindow.delegate = self
        
        // Connect the Esc callback
        clipboardWindow.onEsc = { [weak self] in
            self?.closeClipboardWindow()
        }
        
        let clipboardView = ClipboardHistoryView(store: clipboardStore) { [weak self] in
            self?.closeClipboardWindow()
        }
        clipboardWindow.contentView = NSHostingView(rootView: clipboardView)
    }
    
    // Handle the red 'X' button manually to trigger our close logic
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === clipboardWindow {
            closeClipboardWindow()
            return false 
        }
        return true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win === clipboardWindow {
            DispatchQueue.main.async {
                if self.clipboardWindow.isVisible {
                    self.closeClipboardWindow()
                }
            }
        }
    }
    
    func toggleClipboardWindow() {
        if clipboardWindow.isVisible {
            closeClipboardWindow()
        } else {
            showClipboardWindow()
        }
    }
    
    func showClipboardWindow() {
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            if currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp = currentApp
            } else {
                previousApp = nil
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
        clipboardWindow.center()
        clipboardWindow.makeKeyAndOrderFront(nil)
    }
    
    func closeClipboardWindow() {
        guard clipboardWindow.isVisible else { return }
        
        clipboardWindow.orderOut(nil)
        
        if let prev = previousApp {
            prev.activate(options: [])
            previousApp = nil
        } else {
            // Fallback: If no previous app, ensure we don't leave the user hanging
            if !window.isVisible || window.isMiniaturized {
                NSApp.hide(nil)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        mouseInterceptor?.stop()
        keyboardInterceptor?.stop()
        clipboardStore.stopMonitoring()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About FineTerm", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit FineTerm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        mainMenu.addItem(editMenuItem)
        let editMenu = editMenuItem.submenu!
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }

    @objc func openSettings() {
        NotificationCenter.default.post(name: Notification.Name("FineTermOpenSettings"), object: nil)
        if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
