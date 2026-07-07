# Requirements Document

## Introduction

This document specifies the requirements for adding native Apple Silicon (arm64) support to the MarkdownReader macOS application. Currently, the project only produces Intel (x86_64) binaries via the `build-intel-app.sh` script. This feature adds the ability to build native arm64 binaries and universal (fat) binaries that run natively on both Intel and Apple Silicon Macs.

## Glossary

- **Build_System**: The collection of scripts and Swift Package Manager configuration that compiles the MarkdownReader application into distributable binaries
- **Universal_Binary**: A macOS executable containing both x86_64 and arm64 architecture slices, enabling native execution on Intel and Apple Silicon hardware
- **App_Bundle**: The `.app` directory structure containing the executable, resources, and metadata required for macOS application distribution
- **CI_Pipeline**: The GitHub Actions workflow that validates, builds, tests, and packages the application
- **Code_Signing_Service**: The component responsible for ad-hoc or identity-based signing of the produced application bundle

## Requirements

### Requirement 1: Native arm64 Build Script

**User Story:** As a developer, I want a build script that produces a native arm64 binary, so that I can distribute an Apple Silicon-optimized version of the application.

#### Acceptance Criteria

1. WHEN the arm64 build script is executed, THE Build_System SHALL compile the MarkdownReader-macOS product in the release configuration targeting the arm64 architecture
2. WHEN the arm64 build completes successfully, THE Build_System SHALL produce an App_Bundle containing the arm64 executable at `Contents/MacOS/`, an `Info.plist` at `Contents/`, and any resource bundles at `Contents/Resources/`
3. WHEN the arm64 App_Bundle is produced, THE Build_System SHALL sign the bundle using ad-hoc code signing
4. WHEN the arm64 App_Bundle is signed, THE Build_System SHALL verify the code signature passes strict validation before proceeding to archive creation
5. WHEN code signature validation succeeds, THE Build_System SHALL create a compressed zip archive named `MarkdownReader-macOS-arm64.zip` in the `dist` directory
6. WHEN the arm64 build completes, THE Build_System SHALL verify the produced binary contains only the arm64 architecture slice
7. IF the architecture verification determines the binary contains a non-arm64 slice, THEN THE Build_System SHALL exit with a non-zero status and an error message indicating the unexpected architectures found

### Requirement 2: Universal Binary Build Script

**User Story:** As a developer, I want a build script that produces a universal binary, so that I can distribute a single application that runs natively on both Intel and Apple Silicon Macs.

#### Acceptance Criteria

1. WHEN the universal build script is executed, THE Build_System SHALL compile the MarkdownReader-macOS product in release configuration for both x86_64 and arm64 architectures
2. WHEN both architecture builds complete, THE Build_System SHALL combine the two binaries into a single universal executable using `lipo`
3. WHEN the universal App_Bundle is produced, THE Build_System SHALL structure the bundle with a Contents/MacOS directory containing the universal executable, a Contents/Resources directory, and a Contents/Info.plist copied from the project's Packaging directory
4. WHEN the universal App_Bundle is structured, THE Build_System SHALL sign the bundle using ad-hoc code signing
5. WHEN the universal App_Bundle is signed, THE Build_System SHALL create a compressed zip archive named `MarkdownReader-macOS-universal.zip` in the `dist` directory
6. WHEN the universal build completes, THE Build_System SHALL verify the produced binary contains both x86_64 and arm64 architecture slices and that code signing is valid
7. IF architecture verification or code signing verification fails, THEN THE Build_System SHALL exit with a non-zero status code and output an error message indicating which verification failed
8. WHEN resource bundles (directories matching `*.bundle`) exist in the build output, THE Build_System SHALL include those resource bundles in the universal App_Bundle's Contents/Resources directory
9. IF either architecture build fails, THEN THE Build_System SHALL exit with a non-zero status code and output an error message indicating which architecture failed to compile

### Requirement 3: CI Pipeline Architecture Support

**User Story:** As a developer, I want the CI pipeline to build and test on Apple Silicon runners, so that I can verify the application works correctly on arm64 before release.

#### Acceptance Criteria

1. WHEN the CI pipeline runs the test suite, THE CI_Pipeline SHALL execute tests for both x86_64 and arm64 architectures as independent jobs, so that a failure in one architecture does not prevent the other from completing
2. WHEN a release event is published, THE CI_Pipeline SHALL produce arm64, x86_64, and universal binary variants using the corresponding build scripts
3. WHEN release artifacts are produced, THE CI_Pipeline SHALL upload each architecture variant as a separate build artifact with a name that includes the architecture identifier (arm64, x86_64, or universal) and retain artifacts for at least 30 days
4. IF a build or test fails for one architecture but succeeds for another, THEN THE CI_Pipeline SHALL report the failure with the architecture name included in the job name and status output, and SHALL NOT mark the successful architecture as failed
5. WHEN the CI pipeline executes architecture-specific test jobs, THE CI_Pipeline SHALL run arm64 tests on an Apple Silicon runner and x86_64 tests on an Intel runner

### Requirement 4: Build Script Isolation

**User Story:** As a developer, I want each architecture build to use its own scratch directory, so that build artifacts from different architectures do not interfere with each other.

#### Acceptance Criteria

1. THE Build_System SHALL use a distinct scratch path for each architecture variant (arm64, x86_64, universal) such that no two build scripts share or nest within the same scratch directory
2. THE Build_System SHALL isolate module caches (Clang module cache, SwiftPM module cache, and XDG cache) under each architecture's own scratch path
3. WHEN multiple build scripts are executed in sequence, THE Build_System SHALL produce a valid App_Bundle with the expected architecture slices for each script, regardless of execution order
4. THE Build_System SHALL ensure that no build script reads from or writes to another architecture's scratch directory

### Requirement 5: Existing Intel Build Preservation

**User Story:** As a developer, I want the existing Intel build process to remain unchanged, so that I do not break the current distribution workflow.

#### Acceptance Criteria

1. THE Build_System SHALL retain the existing `build-intel-app.sh` script with identical file contents to its state prior to the addition of arm64 or universal build scripts
2. WHEN the Intel build script is executed after the arm64 or universal build scripts have been added to the project, THE Build_System SHALL produce an App_Bundle containing an x86_64-only executable, signed with ad-hoc code signing, and structured with the same directory layout (`Contents/MacOS`, `Contents/Resources`, `Contents/Info.plist`)
3. WHEN the Intel build script completes successfully, THE Build_System SHALL produce the `MarkdownReader-macOS-x86_64.zip` archive in the `dist` directory
4. WHEN the Intel build script is executed after another architecture build has run, THE Build_System SHALL use its dedicated scratch path (`.build-intel`) without reading from or writing to scratch paths used by arm64 or universal builds

### Requirement 6: Build Validation

**User Story:** As a developer, I want each build script to validate the produced binary, so that I can be confident the correct architectures are present before distribution.

#### Acceptance Criteria

1. WHEN a build completes and before creating the distribution archive, THE Build_System SHALL verify the executable architecture using `lipo -archs` and confirm the output matches the expected architectures for that build type (arm64 for the arm64 build script, x86_64 for the Intel build script, and both x86_64 and arm64 for the universal build script)
2. IF the architecture verification fails, THEN THE Build_System SHALL exit with a non-zero status code and print a diagnostic message identifying the expected and actual architectures
3. WHEN a build completes and before creating the distribution archive, THE Build_System SHALL validate the Info.plist using `plutil -lint`
4. WHEN a build completes and before creating the distribution archive, THE Build_System SHALL verify the code signature using `codesign --verify --deep --strict`
5. IF any validation step fails, THEN THE Build_System SHALL halt execution immediately without running subsequent validation steps, exit with a non-zero status code, and report which validation step failed and the reason for the failure
