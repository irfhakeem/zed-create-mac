import Foundation

public struct DirectoryScanner {
    public let rootPath: String
    
    private static let defaultIgnoredDirectories: Set<String> = [
        ".git",
        "node_modules",
        ".build",
        ".next",
        ".nuxt",
        "dist",
        "out",
        "target",
        "vendor",
        ".turbo",
        ".cache",
        ".idea",
        ".vscode",
        ".zed",
        "Pods",
        "DerivedData",
        "__pycache__",
        ".venv",
        "venv",
        "env",
        "build",
        "bin",
        "obj"
    ]
    
    public init(rootPath: String) {
        self.rootPath = (rootPath as NSString).standardizingPath
    }
    
    public func scanDirectories() -> [String] {
        var directories: [String] = ["./"]
        let rootURL = URL(fileURLWithPath: rootPath)
        let rootCanonical = rootURL.resolvingSymlinksInPath().path
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            return directories
        }
        
        let gitignorePatterns = loadGitignorePatterns(rootURL: rootURL)
        
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsPackageDescendants]
        ) else {
            return directories
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                  resourceValues.isDirectory == true,
                  resourceValues.isPackage != true else {
                continue
            }
            
            let fileCanonical = fileURL.resolvingSymlinksInPath().path
            var relativePath = fileCanonical
            if fileCanonical.hasPrefix(rootCanonical) {
                relativePath = String(fileCanonical.dropFirst(rootCanonical.count))
            } else if fileURL.path.hasPrefix(rootPath) {
                relativePath = String(fileURL.path.dropFirst(rootPath.count))
            }
            relativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if relativePath.isEmpty { continue }
            
            let pathComponents = relativePath.components(separatedBy: "/")
            let lastComponent = pathComponents.last ?? ""
            
            if DirectoryScanner.defaultIgnoredDirectories.contains(lastComponent) ||
               (lastComponent.hasPrefix(".") && lastComponent != ".") {
                enumerator.skipDescendants()
                continue
            }
            
            if shouldIgnore(path: relativePath, patterns: gitignorePatterns) {
                enumerator.skipDescendants()
                continue
            }
            
            directories.append("./" + relativePath)
            
            if directories.count >= 10000 {
                break
            }
        }
        
        return directories.sorted { (a, b) -> Bool in
            if a == "./" { return true }
            if b == "./" { return false }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
    }
    
    private func loadGitignorePatterns(rootURL: URL) -> [String] {
        let gitignoreURL = rootURL.appendingPathComponent(".gitignore")
        guard let content = try? String(contentsOf: gitignoreURL, encoding: .utf8) else {
            return []
        }
        
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
    
    private func shouldIgnore(path: String, patterns: [String]) -> Bool {
        let components = path.components(separatedBy: "/")
        for pattern in patterns {
            let cleanPattern = pattern.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if cleanPattern.isEmpty { continue }
            if components.contains(cleanPattern) {
                return true
            }
            if path == cleanPattern || path.hasPrefix(cleanPattern + "/") {
                return true
            }
        }
        return false
    }
}
