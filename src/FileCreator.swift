import Foundation

public struct FileCreator {
    public static func create(
        rootPath: String,
        selectedDirectory: String,
        input: String
    ) throws -> [String] {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return [] }
        
        var dirRelative = selectedDirectory
        if dirRelative.hasPrefix("./") {
            dirRelative = String(dirRelative.dropFirst(2))
        }
        
        let targetDir = (rootPath as NSString).appendingPathComponent(dirRelative)
        let expandedNames = expandPatterns(input: trimmedInput)
        var createdPaths: [String] = []
        let fileManager = FileManager.default
        
        for name in expandedNames {
            let fullPath = (targetDir as NSString).appendingPathComponent(name)
            let isDirectory = name.hasSuffix("/")
            
            if isDirectory {
                try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil)
                createdPaths.append(fullPath)
            } else {
                let parentDir = (fullPath as NSString).deletingLastPathComponent
                if !fileManager.fileExists(atPath: parentDir) {
                    try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true, attributes: nil)
                }
                
                if !fileManager.fileExists(atPath: fullPath) {
                    fileManager.createFile(atPath: fullPath, contents: Data(), attributes: nil)
                }
                createdPaths.append(fullPath)
            }
        }
        
        return createdPaths
    }
    
    public static func expandPatterns(input: String) -> [String] {
        let items: [String]
        if !input.contains("{") {
            items = input.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else {
            items = [input]
        }
        
        var results: [String] = []
        for item in items {
            results.append(contentsOf: expandBraces(pattern: item))
        }
        return results
    }
    
    public static func expandBraces(pattern: String) -> [String] {
        guard let openIdx = pattern.firstIndex(of: "{"),
              let closeIdx = pattern.firstIndex(of: "}"),
              openIdx < closeIdx else {
            return [pattern]
        }
        
        let prefix = String(pattern[..<openIdx])
        let suffix = String(pattern[pattern.index(after: closeIdx)...])
        let inside = String(pattern[pattern.index(after: openIdx)..<closeIdx])
        
        let options = inside.components(separatedBy: ",")
        var expanded: [String] = []
        
        for option in options {
            let candidate = prefix + option + suffix
            expanded.append(contentsOf: expandBraces(pattern: candidate))
        }
        
        return expanded
    }
    
    public static func openInZed(filePaths: [String]) {
        guard !filePaths.isEmpty else { return }
        
        let zedPath: String
        let candidates = [
            "/opt/homebrew/bin/zed",
            "/usr/local/bin/zed",
            "/Applications/Zed.app/Contents/MacOS/zed"
        ]
        
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            zedPath = found
        } else {
            zedPath = "zed"
        }
        
        let filesToOpen = filePaths.filter { path in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            return !isDir.boolValue
        }
        
        let targets = filesToOpen.isEmpty ? filePaths : filesToOpen
        let process = Process()
        if zedPath.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: zedPath)
            process.arguments = targets
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["zed"] + targets
        }
        try? process.run()
    }
}
