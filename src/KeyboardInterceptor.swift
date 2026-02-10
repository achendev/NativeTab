import Cocoa
import ApplicationServices

private var globalKeyboardEventTap: CFMachPort?

// State for the Origin Loop (Origin -> FineTerm -> Terminal -> Origin)
private var savedOriginBundleID: String?

class KeyboardInterceptor {
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    static func getKeyCode(for char: String) -> CGKeyCode? {
        let lower = char.lowercased()
        switch lower {
            case "a": return 0
            case "s": return 1
            case "d": return 2
            case "f": return 3
            case "h": return 4
            case "g": return 5
            case "z": return 6
            case "x": return 7
            case "c": return 8
            case "v": return 9
            case "b": return 11
            case "q": return 12
            case "w": return 13
            case "e": return 14
            case "r": return 15
            case "y": return 16
            case "t": return 17
            case "1": return 18
            case "2": return 19
            case "3": return 20
            case "4": return 21
            case "6": return 22
            case "5": return 23
            case "=": return 24
            case "9": return 25
            case "7": return 26
            case "-": return 27
            case "8": return 28
            case "0": return 29
            case "]": return 30
            case "o": return 31
            case "u": return 32
            case "[": return 33
            case "i": return 34
            case "p": return 35
            case "l": return 37
            case "j": return 38
            case "'": return 39
            case "k": return 40
            case ";": return 41
            case "\\": return 42
            case ",": return 43
            case "/": return 44
            case "n": return 45
            case "m": return 46
            case ".": return 47
            default: return nil
        }
    }

    func start() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keyboardEventCallback,
            userInfo: nil
        ) else { return }

        self.eventTap = tap
        globalKeyboardEventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let rls = self.runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let rls = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rls, .commonModes)
            }
        }
        globalKeyboardEventTap = nil
        eventTap = nil
        runLoopSource = nil
        savedOriginBundleID = nil
    }
}

func isModifierMatch(flags: CGEventFlags, targetStr: String) -> Bool {
    switch targetStr {
        case "command": 
            return flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate)
        case "control": 
            return flags.contains(.maskControl) && !flags.contains(.maskCommand) && !flags.contains(.maskAlternate)
        case "option":  
            return flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl)
        default: 
            return false
    }
}

// Helpers for Activation
func activateApp(bundleID: String) {
    let workspace = NSWorkspace.shared
    
    // Attempt to find the URL for the app
    guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
        print("DEBUG: Could not find URL for bundle ID: \(bundleID)")
        return
    }
    
    // Robust Activation using OpenConfiguration (Equivalent to Dock click)
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    
    workspace.openApplication(at: url, configuration: config) { app, error in
        if let error = error {
            print("DEBUG: Failed to activate \(bundleID): \(error)")
        } else {
            print("DEBUG: Successfully requested activation for \(bundleID)")
        }
    }
}

func activateFineTerm() {
    DispatchQueue.main.async {
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let window = appDelegate.window else { return }

        // 1. Visual Prep: Unhide and Deminiaturize
        NSApp.unhide(nil)
        if window.isMiniaturized { window.deminiaturize(nil) }
        
        // 2. Logic: Snap
        if UserDefaults.standard.bool(forKey: AppConfig.Keys.snapToTerminal) {
            appDelegate.snapToTerminal()
        }

        // 3. Window System: Order Front
        // "orderFrontRegardless" allows the window to move to the active space or appear above others
        // crucial when coming from another Space.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // 4. Application: Activate
        // We use NSApp.activate because it works within the app context.
        // Doing this AFTER orderFront tells the system "This specific window is the reason we are activating".
        NSApp.activate(ignoringOtherApps: true)
        
        // 5. CRITICAL FIX for Space Switching Lag:
        // When switching Spaces (e.g. from Chrome on Space 2 to FineTerm on Space 1), 
        // macOS initially focuses the *last active app* on Space 1 (Terminal) before processing 
        // our activation request. This creates a race condition where FineTerm appears but 
        // Terminal keeps focus (gray search bar).
        // We must re-assert focus after a tiny delay to ensure we win the tug-of-war.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        
        // 6. Secondary Safety Net
        // If the space switch animation is slow (e.g. ProMotion disabled or old Mac), retry slightly later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

func activateTerminal() {
    DispatchQueue.main.async {
        activateApp(bundleID: "com.apple.Terminal")
    }
}

// Helper to get real front app, mitigating NSWorkspace lag
func getRealFrontmostApp() -> NSRunningApplication? {
    let workspaceApp = NSWorkspace.shared.frontmostApplication
    
    // If NSWorkspace says it's NOT Terminal, trust it (optimization)
    if let id = workspaceApp?.bundleIdentifier, id != "com.apple.Terminal" {
        return workspaceApp
    }
    
    // If NSWorkspace says Terminal, verify with Window List (Z-Order)
    // This catches the case where user just clicked Chrome, but NSWorkspace hasn't updated yet.
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return workspaceApp
    }
    
    for info in list {
        if let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber {
            let pid = pidNumber.int32Value
            if let app = NSRunningApplication(processIdentifier: pid) {
                // Return first regular app
                if app.activationPolicy == .regular {
                    return app
                }
            }
        }
    }
    
    return workspaceApp
}

func keyboardEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = globalKeyboardEventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    
    let flags = event.flags
    let hasModifier = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)
    if !hasModifier { return Unmanaged.passUnretained(event) }
    
    let defaults = UserDefaults.standard
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let debug = defaults.bool(forKey: AppConfig.Keys.debugMode)
    
    // CHECK 1: Main Shortcut (The Activation Loop)
    let mainKey = defaults.string(forKey: AppConfig.Keys.globalShortcutKey) ?? "n"
    let mainMod = defaults.string(forKey: AppConfig.Keys.globalShortcutModifier) ?? "command"
    let mainAnywhere = defaults.bool(forKey: AppConfig.Keys.globalShortcutAnywhere)
    let secondActivation = defaults.bool(forKey: AppConfig.Keys.secondActivationToTerminal)
    let thirdActivation = defaults.bool(forKey: AppConfig.Keys.thirdActivationToOrigin)
    
    // Mitigate Lag: Use getRealFrontmostApp instead of NSWorkspace directly
    let frontApp = getRealFrontmostApp()
    let isTerminalFront = frontApp?.bundleIdentifier == "com.apple.Terminal"
    let isFineTermFront = NSRunningApplication.current.isActive // Reliable for own app check
    
    if let mainCode = KeyboardInterceptor.getKeyCode(for: mainKey),
       keyCode == Int64(mainCode),
       isModifierMatch(flags: flags, targetStr: mainMod) {
        
        // Safety: If global anywhere is off, we only care if we are in Terminal, FineTerm, or it's a valid trigger context
        if !mainAnywhere && !isTerminalFront && !isFineTermFront {
             return Unmanaged.passUnretained(event)
        }
        
        if debug { print("DEBUG: Shortcut Pressed. Front: \(frontApp?.localizedName ?? "Unknown")") }
        
        // --- LOOP LOGIC ---
        
        // 1. FineTerm -> Terminal
        if isFineTermFront {
            if secondActivation {
                if debug { print("DEBUG: Loop Step 2: FineTerm -> Terminal") }
                activateTerminal()
                return nil // Swallow event
            }
            return Unmanaged.passUnretained(event)
        }
        
        // 2. Terminal -> Origin (or FineTerm)
        if isTerminalFront {
            if secondActivation && thirdActivation,
               let originID = savedOriginBundleID,
               originID != "com.apple.Terminal",
               originID != Bundle.main.bundleIdentifier {
                
                if debug { print("DEBUG: Loop Step 3: Terminal -> Origin (\(originID))") }
                DispatchQueue.main.async {
                    activateApp(bundleID: originID)
                }
                return nil // Swallow event
            }
            
            // Fallback: Terminal -> FineTerm
            if debug { print("DEBUG: Loop Step 3 (Fallback): Terminal -> FineTerm") }
            activateFineTerm()
            return nil
        }
        
        // 3. Origin -> FineTerm
        if !isFineTermFront && !isTerminalFront {
            if let app = frontApp, let bundleID = app.bundleIdentifier {
                savedOriginBundleID = bundleID
                if debug { print("DEBUG: Loop Step 1: Origin (\(app.localizedName ?? bundleID)) -> FineTerm") }
            } else {
                if debug { print("DEBUG: Loop Step 1: Unknown Origin -> FineTerm") }
            }
            
            activateFineTerm()
            return nil
        }
    }
    
    // CHECK 2: Clipboard Shortcut
    if defaults.bool(forKey: AppConfig.Keys.enableClipboardManager) {
        let clipKey = defaults.string(forKey: AppConfig.Keys.clipboardShortcutKey) ?? "u"
        let clipMod = defaults.string(forKey: AppConfig.Keys.clipboardShortcutModifier) ?? "command"
        
        if let clipCode = KeyboardInterceptor.getKeyCode(for: clipKey),
           keyCode == Int64(clipCode),
           isModifierMatch(flags: flags, targetStr: clipMod) {
            
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.toggleClipboardWindow()
                }
            }
            return nil
        }
    }
    
    return Unmanaged.passUnretained(event)
}