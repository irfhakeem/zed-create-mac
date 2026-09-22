import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: PureModalController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = ProcessInfo.processInfo.environment
        var rootPath = FileManager.default.currentDirectoryPath
        var activeFile: String? = nil
        
        if CommandLine.arguments.count > 1 {
            let arg = CommandLine.arguments[1]
            if !arg.isEmpty && !arg.hasPrefix("$") && FileManager.default.fileExists(atPath: arg) {
                rootPath = arg
            }
        } else if let envRoot = env["ZED_WORKTREE_ROOT"], !envRoot.isEmpty, FileManager.default.fileExists(atPath: envRoot) {
            rootPath = envRoot
        }
        
        if CommandLine.arguments.count > 2 {
            let arg = CommandLine.arguments[2]
            if !arg.isEmpty && !arg.hasPrefix("$") {
                activeFile = arg
            }
        } else if let envFile = env["ZED_FILE"], !envFile.isEmpty {
            activeFile = envFile
        }
        
        controller = PureModalController(rootPath: rootPath, activeFilePath: activeFile)
        controller.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
