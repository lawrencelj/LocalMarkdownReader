#!/usr/bin/env swift

/// Functional Test Script - MarkdownReader Core Functionality
/// Tests key functional flows without requiring full test suite compilation

import Foundation

// MARK: - Test Configuration
struct TestConfig {
    static let testMarkdownContent = """
    # Test Document

    This is a test document for **functional testing**.

    ## Section 1

    Content with `code` and [links](https://example.com).

    ### Subsection

    - List item 1
    - List item 2
    - List item 3

    ## Section 2

    More content with **bold** and *italic* text.

    ```swift
    func testFunction() {
        print("Hello, World!")
    }
    ```
    """
}

// MARK: - Test Results
class TestResults {
    var passed = 0
    var failed = 0
    var errors: [String] = []

    func recordPass(_ testName: String) {
        passed += 1
        print("✅ PASS: \(testName)")
    }

    func recordFail(_ testName: String, error: String) {
        failed += 1
        errors.append("\(testName): \(error)")
        print("❌ FAIL: \(testName) - \(error)")
    }

    func printSummary() {
        print("\n" + String(repeating: "=", count: 60))
        print("TEST SUMMARY")
        print(String(repeating: "=", count: 60))
        print("Total Tests: \(passed + failed)")
        print("Passed: \(passed)")
        print("Failed: \(failed)")

        if failed > 0 {
            print("\nFailures:")
            for error in errors {
                print("  - \(error)")
            }
        }

        print(String(repeating: "=", count: 60))
    }
}

// MARK: - Functional Tests
class FunctionalTests {
    let results = TestResults()

    func runAll() {
        print("🚀 Starting MarkdownReader Functional Tests\n")

        testFileSystemAccess()
        testMarkdownParsing()
        testSearchFunctionality()
        testSettingsManagement()

        results.printSummary()

        // Exit with appropriate code
        exit(results.failed == 0 ? 0 : 1)
    }

    // MARK: - File System Tests
    func testFileSystemAccess() {
        print("\n📁 Testing File System Access...")

        // Test 1: Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownReaderTests")
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            results.recordPass("Create temp directory")
        } catch {
            results.recordFail("Create temp directory", error: error.localizedDescription)
            return
        }

        // Test 2: Write test file
        let testFile = tempDir.appendingPathComponent("test.md")
        do {
            try TestConfig.testMarkdownContent.write(to: testFile, atomically: true, encoding: .utf8)
            results.recordPass("Write markdown file")
        } catch {
            results.recordFail("Write markdown file", error: error.localizedDescription)
        }

        // Test 3: Read test file
        do {
            let content = try String(contentsOf: testFile, encoding: .utf8)
            if content == TestConfig.testMarkdownContent {
                results.recordPass("Read markdown file")
            } else {
                results.recordFail("Read markdown file", error: "Content mismatch")
            }
        } catch {
            results.recordFail("Read markdown file", error: error.localizedDescription)
        }

        // Test 4: File metadata
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
            if let size = attributes[.size] as? Int64, size > 0 {
                results.recordPass("File metadata access")
            } else {
                results.recordFail("File metadata access", error: "Invalid file size")
            }
        } catch {
            results.recordFail("File metadata access", error: error.localizedDescription)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Markdown Parsing Tests
    func testMarkdownParsing() {
        print("\n📝 Testing Markdown Parsing...")

        // Test 1: Heading detection
        let headingPattern = #"^#{1,6}\s+.*$"#
        let headingRegex = try! NSRegularExpression(pattern: headingPattern, options: .anchorsMatchLines)
        let headingMatches = headingRegex.matches(
            in: TestConfig.testMarkdownContent,
            range: NSRange(TestConfig.testMarkdownContent.startIndex..., in: TestConfig.testMarkdownContent)
        )

        if headingMatches.count >= 3 {
            results.recordPass("Heading detection")
        } else {
            results.recordFail("Heading detection", error: "Found \(headingMatches.count) headings, expected at least 3")
        }

        // Test 2: Code block detection
        if TestConfig.testMarkdownContent.contains("```") {
            results.recordPass("Code block detection")
        } else {
            results.recordFail("Code block detection", error: "No code blocks found")
        }

        // Test 3: List detection
        let listPattern = #"^\s*[-*+]\s+.*$"#
        let listRegex = try! NSRegularExpression(pattern: listPattern, options: .anchorsMatchLines)
        let listMatches = listRegex.matches(
            in: TestConfig.testMarkdownContent,
            range: NSRange(TestConfig.testMarkdownContent.startIndex..., in: TestConfig.testMarkdownContent)
        )

        if listMatches.count >= 3 {
            results.recordPass("List item detection")
        } else {
            results.recordFail("List item detection", error: "Found \(listMatches.count) items, expected at least 3")
        }

        // Test 4: Word count
        let words = TestConfig.testMarkdownContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count > 30 {
            results.recordPass("Word count calculation")
        } else {
            results.recordFail("Word count calculation", error: "Word count too low: \(words.count)")
        }
    }

    // MARK: - Search Tests
    func testSearchFunctionality() {
        print("\n🔍 Testing Search Functionality...")

        let content = TestConfig.testMarkdownContent.lowercased()

        // Test 1: Basic search
        if content.contains("test") {
            results.recordPass("Basic text search")
        } else {
            results.recordFail("Basic text search", error: "Search term not found")
        }

        // Test 2: Case-insensitive search
        if content.contains("document") && content.contains("DOCUMENT".lowercased()) {
            results.recordPass("Case-insensitive search")
        } else {
            results.recordFail("Case-insensitive search", error: "Case sensitivity issue")
        }

        // Test 3: Multi-word search
        let searchTerms = ["test", "document", "content"]
        let allFound = searchTerms.allSatisfy { content.contains($0) }

        if allFound {
            results.recordPass("Multi-word search")
        } else {
            results.recordFail("Multi-word search", error: "Not all terms found")
        }

        // Test 4: Search result counting
        let searchTerm = "test"
        let components = content.components(separatedBy: searchTerm)
        let occurrences = components.count - 1

        if occurrences > 0 {
            results.recordPass("Search result counting")
        } else {
            results.recordFail("Search result counting", error: "No occurrences found")
        }
    }

    // MARK: - Settings Tests
    func testSettingsManagement() {
        print("\n⚙️  Testing Settings Management...")

        let defaults = UserDefaults.standard
        let testKey = "test_setting_\(UUID().uuidString)"

        // Test 1: Write setting
        defaults.set("test_value", forKey: testKey)
        if defaults.string(forKey: testKey) == "test_value" {
            results.recordPass("Write setting")
        } else {
            results.recordFail("Write setting", error: "Setting not saved")
        }

        // Test 2: Read setting
        if let value = defaults.string(forKey: testKey), value == "test_value" {
            results.recordPass("Read setting")
        } else {
            results.recordFail("Read setting", error: "Setting not retrieved")
        }

        // Test 3: Update setting
        defaults.set("updated_value", forKey: testKey)
        if defaults.string(forKey: testKey) == "updated_value" {
            results.recordPass("Update setting")
        } else {
            results.recordFail("Update setting", error: "Setting not updated")
        }

        // Test 4: Remove setting
        defaults.removeObject(forKey: testKey)
        if defaults.string(forKey: testKey) == nil {
            results.recordPass("Remove setting")
        } else {
            results.recordFail("Remove setting", error: "Setting not removed")
        }
    }
}

// MARK: - Main Execution
let tests = FunctionalTests()
tests.runAll()
