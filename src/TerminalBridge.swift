import Foundation

struct TerminalBridge {
    static func launch(command: String) {
        // AppleScript to open a new tab and run the command
        // If Terminal is not running, it opens. If running, it makes a new tab.
        let scriptSource = """
        tell application "Terminal"
            activate
            try
                tell application "System Events" to keystroke "t" using command down
            on error
                do script "" -- Fallback if keystroke fails (e.g. no window open)
            end try
            delay 0.2
            do script "\(command)" in front window
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript Error: \(error)")
            }
        }
    }
}
