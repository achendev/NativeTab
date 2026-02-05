import Cocoa
import ApplicationServices

private var globalKeyboardEventTap: CFMachPort?

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
    let frontApp = NSWorkspace.shared.frontmostApplication
    let isTerminalFront = frontApp?.bundleIdentifier == "com.apple.Terminal"
    
    // CHECK 1: Main Shortcut
    let mainKey = defaults.string(forKey: AppConfig.Keys.globalShortcutKey) ?? "n"
    let mainMod = defaults.string(forKey: AppConfig.Keys.globalShortcutModifier) ?? "command"
    let mainAnywhere = defaults.bool(forKey: AppConfig.Keys.globalShortcutAnywhere)
    
    if (mainAnywhere || isTerminalFront),
       let mainCode = KeyboardInterceptor.getKeyCode(for: mainKey),
       keyCode == Int64(mainCode),
       isModifierMatch(flags: flags, targetStr: mainMod) {
        
        if NSApp.isActive { return Unmanaged.passUnretained(event) }
        
        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let window = appDelegate.window {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        return nil
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
