import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: PureModalController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        var rootPath = FileManager.default.currentDirectoryPath
        var activeFile: String? = nil
        
        if CommandLine.arguments.count > 1 {
            let arg = CommandLine.arguments[1]
            if !arg.isEmpty && arg != "$ZED_WORKTREE_ROOT" && FileManager.default.fileExists(atPath: arg) {
                rootPath = arg
            }
        }
        
        if CommandLine.arguments.count > 2 {
            let arg = CommandLine.arguments[2]
            if !arg.isEmpty && arg != "$ZED_FILE" {
                activeFile = arg
            }
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
