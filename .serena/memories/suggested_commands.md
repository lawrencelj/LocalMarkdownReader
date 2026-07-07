# Essential Development Commands

## Project Setup
```bash
# Initial project bootstrap
./Scripts/bootstrap.sh

# Build the project
swift build --configuration debug
swift build --configuration release

# Open in Xcode
open Package.swift
```

## Testing Commands
```bash
# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run performance tests
swift test --filter PerformanceTests

# Generate coverage report
xcrun llvm-cov export .build/debug/MarkdownReaderPackageTests.xctest/Contents/MacOS/MarkdownReaderPackageTests --format="lcov" --instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

## Code Quality & Linting
```bash
# Run SwiftLint (zero-warning policy)
swiftlint --strict --config .swiftlint.yml

# Run SwiftFormat check
swiftformat --lint .

# Apply SwiftFormat fixes
swiftformat .

# Run all quality checks
./Scripts/lint.sh
```

## Build & Run Applications
```bash
# Build iOS application
swift build --configuration debug --product MarkdownReader-iOS

# Build macOS application
swift build --configuration debug --product MarkdownReader-macOS

# Run in Xcode (select appropriate scheme):
# - MarkdownReader-iOS for iOS simulator/device
# - MarkdownReader-macOS for macOS native
```

## Documentation
```bash
# Generate DocC documentation
swift package --allow-writing-to-directory ./docs generate-documentation --target MarkdownCore --disable-indexing --transform-for-static-hosting --hosting-base-path SwiftMarkdownReader --output-path ./docs
```

## Git Workflow
```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Before committing (quality gates)
./Scripts/lint.sh
swift test

# Commit with conventional format
git commit -m "feat: implement markdown rendering with syntax highlighting"

# Push and create PR
git push origin feature/your-feature-name
```

## macOS System Commands
```bash
# File search
find . -name "*.swift" -type f
mdfind -name "*.swift"

# Process monitoring
ps aux | grep MarkdownReader

# System info
sw_vers          # macOS version
xcode-select -p  # Xcode path
xcrun --show-sdk-version  # SDK version
```

## Performance Profiling
```bash
# Build for profiling
swift build --configuration release

# Profile memory usage
leaks --atExit -- ./.build/release/MarkdownReader-macOS

# Profile with Instruments (requires Xcode)
# Use Xcode > Product > Profile with Time Profiler
```