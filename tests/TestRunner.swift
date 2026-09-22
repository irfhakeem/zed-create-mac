import Foundation

@main
struct TestRunner {
    static func main() {
        print("--- Running zed-create Unit Tests ---")

        let expanded1 = FileCreator.expandBraces(pattern: "user.{go,sql}")
        assert(expanded1 == ["user.go", "user.sql"], "expandBraces failed for user.{go,sql}")

        let expanded2 = FileCreator.expandPatterns(input: "a.ts, b.ts")
        assert(expanded2 == ["a.ts", "b.ts"], "expandPatterns failed for comma separated")

        let expanded3 = FileCreator.expandBraces(pattern: "src/{components,utils}/{index,styles}.{ts,css}")
        assert(expanded3.count == 8, "nested expandBraces failed")
        print("✓ Brace expansion tests passed")

        let candidates = [
            "./",
            "./internal",
            "./internal/entity",
            "./internal/repository",
            "./cmd/server"
        ]

        let match1 = FuzzyMatcher.match(query: "entity", candidates: candidates)
        assert(!match1.isEmpty, "FuzzyMatcher should match entity")
        assert(match1.first?.path == "./internal/entity", "Top match should be ./internal/entity")
        print("✓ FuzzyMatcher tests passed")

        let scanner = DirectoryScanner(rootPath: FileManager.default.currentDirectoryPath)
        let scanned = scanner.scanDirectories()
        assert(scanned.contains("./"), "Scanner should always contain ./")
        assert(scanned.contains("./src"), "Scanner should find ./src")
        assert(!scanned.contains("./.git"), "Scanner must ignore .git")
        print("✓ DirectoryScanner tests passed (found \(scanned))")

        let tempDir = NSTemporaryDirectory() + "zed_create_test_" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        do {
            let created = try FileCreator.create(
                rootPath: tempDir,
                selectedDirectory: "./internal/entity",
                input: "user.{go,sql}"
            )
            assert(created.count == 2, "Should have created 2 files")
            assert(FileManager.default.fileExists(atPath: tempDir + "/internal/entity/user.go"), "user.go should exist")
            assert(FileManager.default.fileExists(atPath: tempDir + "/internal/entity/user.sql"), "user.sql should exist")

            let _ = try FileCreator.create(
                rootPath: tempDir,
                selectedDirectory: "./",
                input: "new_service/"
            )
            var isDir: ObjCBool = false
            assert(FileManager.default.fileExists(atPath: tempDir + "/new_service", isDirectory: &isDir) && isDir.boolValue, "new_service/ directory should exist")
            print("✓ FileCreator filesystem tests passed")
        } catch {
            assertionFailure("FileCreator threw error: \(error)")
        }

        print("All tests passed successfully!")
    }
}
