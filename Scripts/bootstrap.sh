#!/bin/bash

#
# bootstrap.sh
# SwiftMarkdownReader Development Environment Setup
#
# Enterprise Platform Cluster - Development Environment Automation
# Validates and configures complete Swift development environment
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
REQUIRED_XCODE_VERSION="15.0"
REQUIRED_SWIFT_VERSION="5.9"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script requires macOS for iOS/macOS development"
        exit 1
    fi
    log_success "Running on macOS"
}

# Check Xcode installation and version
check_xcode() {
    log_info "Checking Xcode installation..."

    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed or command line tools are missing"
        log_info "Please install Xcode from the App Store and run: xcode-select --install"
        exit 1
    fi

    local xcode_version
    xcode_version=$(xcodebuild -version | head -n1 | awk '{print $2}')

    if [[ $(echo "$xcode_version >= $REQUIRED_XCODE_VERSION" | bc -l) -eq 0 ]]; then
        log_warning "Xcode version $xcode_version detected, but $REQUIRED_XCODE_VERSION+ recommended"
    else
        log_success "Xcode $xcode_version meets requirements"
    fi

    # Ensure command line tools are properly configured
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    log_success "Command line tools configured"
}

# Check Swift version
check_swift() {
    log_info "Checking Swift version..."

    if ! command -v swift &> /dev/null; then
        log_error "Swift is not available"
        exit 1
    fi

    local swift_version
    swift_version=$(swift --version | head -n1 | awk '{print $4}')

    if [[ $(echo "$swift_version >= $REQUIRED_SWIFT_VERSION" | bc -l) -eq 0 ]]; then
        log_warning "Swift version $swift_version detected, but $REQUIRED_SWIFT_VERSION+ recommended"
    else
        log_success "Swift $swift_version meets requirements"
    fi
}

# Install and configure SwiftLint
setup_swiftlint() {
    log_info "Setting up SwiftLint..."

    if command -v swiftlint &> /dev/null; then
        local current_version
        current_version=$(swiftlint version)
        log_success "SwiftLint $current_version already installed"
    else
        log_info "Installing SwiftLint via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install swiftlint
        else
            log_error "Homebrew not found. Please install Homebrew first: https://brew.sh"
            exit 1
        fi
        log_success "SwiftLint installed"
    fi

    # Validate SwiftLint configuration
    if [[ -f "$PROJECT_ROOT/.swiftlint.yml" ]]; then
        if swiftlint --config "$PROJECT_ROOT/.swiftlint.yml" --quiet; then
            log_success "SwiftLint configuration validated"
        else
            log_error "SwiftLint configuration has issues"
            exit 1
        fi
    else
        log_warning "SwiftLint configuration not found"
    fi
}

# Install and configure SwiftFormat
setup_swiftformat() {
    log_info "Setting up SwiftFormat..."

    if command -v swiftformat &> /dev/null; then
        local current_version
        current_version=$(swiftformat --version)
        log_success "SwiftFormat $current_version already installed"
    else
        log_info "Installing SwiftFormat via Homebrew..."
        brew install swiftformat
        log_success "SwiftFormat installed"
    fi

    # Validate SwiftFormat configuration
    if [[ -f "$PROJECT_ROOT/.swiftformat" ]]; then
        if swiftformat --lint --config "$PROJECT_ROOT/.swiftformat" "$PROJECT_ROOT" &> /dev/null; then
            log_success "SwiftFormat configuration validated"
        else
            log_warning "SwiftFormat found formatting issues (will be fixed on first run)"
        fi
    else
        log_warning "SwiftFormat configuration not found"
    fi
}

# Install Fastlane for iOS/macOS automation
setup_fastlane() {
    log_info "Setting up Fastlane..."

    if command -v fastlane &> /dev/null; then
        local current_version
        current_version=$(fastlane --version | head -n1 | awk '{print $2}')
        log_success "Fastlane $current_version already installed"
    else
        log_info "Installing Fastlane..."
        # Install using RubyGems
        if command -v gem &> /dev/null; then
            sudo gem install fastlane
        else
            log_error "Ruby/RubyGems not found. Installing via Homebrew..."
            brew install fastlane
        fi
        log_success "Fastlane installed"
    fi
}

# Setup Git hooks for pre-commit validation
setup_git_hooks() {
    log_info "Setting up Git pre-commit hooks..."

    local git_hooks_dir="$PROJECT_ROOT/.git/hooks"
    local pre_commit_hook="$git_hooks_dir/pre-commit"

    if [[ ! -d "$git_hooks_dir" ]]; then
        log_warning "Not a Git repository. Skipping Git hooks setup."
        return
    fi

    # Create pre-commit hook
    cat > "$pre_commit_hook" << 'EOF'
#!/bin/bash
# Pre-commit hook for SwiftMarkdownReader
# Runs SwiftLint and SwiftFormat checks

set -e

echo "🔍 Running pre-commit validation..."

# Run SwiftLint
if command -v swiftlint >/dev/null; then
    if ! swiftlint --quiet; then
        echo "❌ SwiftLint found issues. Please fix them before committing."
        exit 1
    fi
    echo "✅ SwiftLint validation passed"
else
    echo "⚠️  SwiftLint not found. Please run ./Scripts/bootstrap.sh"
fi

# Check SwiftFormat
if command -v swiftformat >/dev/null; then
    if ! swiftformat --lint .; then
        echo "❌ SwiftFormat found formatting issues. Run 'swiftformat .' to fix them."
        exit 1
    fi
    echo "✅ SwiftFormat validation passed"
else
    echo "⚠️  SwiftFormat not found. Please run ./Scripts/bootstrap.sh"
fi

echo "✅ Pre-commit validation completed successfully"
EOF

    chmod +x "$pre_commit_hook"
    log_success "Git pre-commit hook installed"
}

# Validate Swift Package Manager setup
validate_swift_package() {
    log_info "Validating Swift Package Manager setup..."

    cd "$PROJECT_ROOT"

    # Check Package.swift syntax
    if swift package tools-version &> /dev/null; then
        log_success "Package.swift is valid"
    else
        log_error "Package.swift has syntax errors"
        exit 1
    fi

    # Resolve dependencies
    log_info "Resolving Swift package dependencies..."
    if swift package resolve; then
        log_success "Package dependencies resolved"
    else
        log_error "Failed to resolve package dependencies"
        exit 1
    fi

    # Test build
    log_info "Testing package build..."
    if swift build --configuration debug > /dev/null 2>&1; then
        log_success "Package builds successfully"
    else
        log_warning "Package build has issues (this may be expected during initial setup)"
    fi
}

# Create development certificates placeholder
setup_development_certificates() {
    log_info "Setting up development certificates placeholder..."

    local cert_dir="$PROJECT_ROOT/.certificates"
    mkdir -p "$cert_dir"

    cat > "$cert_dir/README.md" << 'EOF'
# Development Certificates

This directory should contain development certificates for code signing.

## Setup Instructions

1. **Development Certificates**:
   - Install development certificates in Keychain Access
   - Ensure certificates are available for Xcode

2. **Distribution Certificates**:
   - For CI/CD: Store certificates in GitHub Secrets
   - For local distribution: Install distribution certificates

3. **Provisioning Profiles**:
   - Download development and distribution profiles
   - Install via Xcode or manually in ~/Library/MobileDevice/Provisioning Profiles/

## Security Notes

- Never commit actual certificates to version control
- Use environment variables or secure storage for CI/CD
- Rotate certificates regularly according to enterprise policy
EOF

    log_success "Development certificates directory created"
}

# Generate project health report
generate_health_report() {
    log_info "Generating development environment health report..."

    local report_file="$PROJECT_ROOT/ENVIRONMENT_HEALTH.md"

    cat > "$report_file" << EOF
# Development Environment Health Report

Generated: $(date)

## System Information
- **Operating System**: $(sw_vers -productName) $(sw_vers -productVersion)
- **Xcode Version**: $(xcodebuild -version | head -n1)
- **Swift Version**: $(swift --version | head -n1)

## Development Tools
- **SwiftLint**: $(command -v swiftlint && swiftlint version || echo "Not installed")
- **SwiftFormat**: $(command -v swiftformat && swiftformat --version || echo "Not installed")
- **Fastlane**: $(command -v fastlane && fastlane --version | head -n1 || echo "Not installed")

## Package Information
- **Package Name**: SwiftMarkdownReader
- **Swift Tools Version**: $(cd "$PROJECT_ROOT" && swift package tools-version)

## Quality Checks
- **SwiftLint Configuration**: $(test -f "$PROJECT_ROOT/.swiftlint.yml" && echo "✅ Present" || echo "❌ Missing")
- **SwiftFormat Configuration**: $(test -f "$PROJECT_ROOT/.swiftformat" && echo "✅ Present" || echo "❌ Missing")
- **Git Pre-commit Hook**: $(test -f "$PROJECT_ROOT/.git/hooks/pre-commit" && echo "✅ Installed" || echo "❌ Not installed")

## Next Steps
1. Run \`swift build\` to build the project
2. Run \`swift test\` to execute tests
3. Use \`swiftlint\` for code quality validation
4. Use \`swiftformat .\` for code formatting

---
Generated by Platform Cluster bootstrap script
EOF

    log_success "Health report generated: $report_file"
}

# Main execution function
main() {
    echo "🚀 SwiftMarkdownReader - Enterprise Development Environment Setup"
    echo "================================================================="
    echo ""

    check_macos
    check_xcode
    check_swift
    setup_swiftlint
    setup_swiftformat
    setup_fastlane
    setup_git_hooks
    validate_swift_package
    setup_development_certificates
    generate_health_report

    echo ""
    echo "================================================================="
    log_success "Development environment setup completed successfully!"
    echo ""
    log_info "Next steps:"
    echo "  1. Review the environment health report: ENVIRONMENT_HEALTH.md"
    echo "  2. Run 'swift build' to build the project"
    echo "  3. Run 'swift test' to execute tests"
    echo "  4. Configure your IDE with the project settings"
    echo ""
    log_info "For help, refer to Documentation/Development/ guides"
}

# Execute main function
main "$@"