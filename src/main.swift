import Cocoa
import SwiftUI

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run the main loop
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
