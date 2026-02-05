import SwiftUI

struct SettingsView: View {
    @AppStorage(AppConfig.Keys.copyOnSelect) private var copyOnSelect = true
    @AppStorage(AppConfig.Keys.pasteOnRightClick) private var pasteOnRightClick = true
    @AppStorage(AppConfig.Keys.debugMode) private var debugMode = false
    
    @AppStorage(AppConfig.Keys.commandPrefix) private var commandPrefix = ""
    @AppStorage(AppConfig.Keys.commandSuffix) private var commandSuffix = ""
    @AppStorage(AppConfig.Keys.changeTerminalName) private var changeTerminalName = true
    
    @AppStorage(AppConfig.Keys.hideCommandInList) private var hideCommandInList = true
    @AppStorage(AppConfig.Keys.smartFilter) private var smartFilter = true
    
    @AppStorage(AppConfig.Keys.globalShortcutKey) private var globalShortcutKey = "n"
    @AppStorage(AppConfig.Keys.globalShortcutModifier) private var globalShortcutModifier = "command"
    @AppStorage(AppConfig.Keys.globalShortcutAnywhere) private var globalShortcutAnywhere = false
    @AppStorage(AppConfig.Keys.secondActivationToTerminal) private var secondActivationToTerminal = true
    @AppStorage(AppConfig.Keys.escToTerminal) private var escToTerminal = false
    
    @AppStorage(AppConfig.Keys.enableClipboardManager) private var enableClipboardManager = false
    @AppStorage(AppConfig.Keys.clipboardShortcutKey) private var clipboardShortcutKey = "u"
    @AppStorage(AppConfig.Keys.clipboardShortcutModifier) private var clipboardShortcutModifier = "command"
    
    @State private var runOnStartup: Bool = LaunchAtLoginManager.isEnabled()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
            }.padding()
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Manager Shortcut").font(.subheadline).fontWeight(.semibold)
                        HStack {
                            Picker("", selection: $globalShortcutModifier) {
                                Text("Command").tag("command"); Text("Control").tag("control"); Text("Option").tag("option")
                            }.frame(width: 100)
                            Text("+")
                            TextField("Key", text: $globalShortcutKey).frame(width: 30)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        Toggle("System-wide (Global)", isOn: $globalShortcutAnywhere)
                        Toggle("Second Activation to Terminal", isOn: $secondActivationToTerminal)
                        Toggle("Esc to Terminal", isOn: $escToTerminal)
                    }
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clipboard Manager").font(.subheadline).fontWeight(.semibold)
                        Toggle("Enable Clipboard Manager", isOn: $enableClipboardManager)
                        if enableClipboardManager {
                            HStack {
                                Text("Shortcut:")
                                Picker("", selection: $clipboardShortcutModifier) {
                                    Text("Command").tag("command"); Text("Control").tag("control"); Text("Option").tag("option")
                                }.frame(width: 90)
                                Text("+")
                                TextField("Key", text: $clipboardShortcutKey).frame(width: 30)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command Wrappers").font(.subheadline).fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prefix:").font(.caption)
                            TextField("e.g. unset HISTFILE", text: $commandPrefix).textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suffix:").font(.caption)
                            TextField("e.g. && exit", text: $commandSuffix).textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        Toggle("Set Terminal Tab Name", isOn: $changeTerminalName)
                    }
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Hide Command in List", isOn: $hideCommandInList)
                        Toggle("Smart Search", isOn: $smartFilter)
                        Toggle("Copy on Select", isOn: $copyOnSelect)
                        Toggle("Paste on Right Click", isOn: $pasteOnRightClick)
                    }
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Run on Startup", isOn: $runOnStartup).onChange(of: runOnStartup) { LaunchAtLoginManager.setEnabled($0) }
                        Toggle("Debug Mode", isOn: $debugMode)
                    }
                }.padding()
            }
            Divider()
            
            HStack {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .frame(maxWidth: .infinity).keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 400, height: 650)
    }
}
