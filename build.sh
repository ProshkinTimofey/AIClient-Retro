#!/bin/bash
# AIClient Build Script
# Usage: ./build.sh [clean|package|install|device|simulator]

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_theos() {
    if [ -z "$THEOS" ]; then
        if [ -d "/opt/theos" ]; then
            export THEOS=/opt/theos
        elif [ -d "$HOME/theos" ]; then
            export THEOS="$HOME/theos"
        else
            log_error "THEOS not set and not found in /opt/theos or ~/theos"
            log_info "Install theos: https://github.com/theos/theos"
            exit 1
        fi
    fi
    log_info "Using THEOS: $THEOS"
}

check_ldid() {
    if ! command -v ldid &> /dev/null; then
        log_warning "ldid not found, installing via brew..."
        brew install ldid || log_error "Failed to install ldid"
    fi
}

clean_build() {
    log_info "Cleaning build artifacts..."
    make clean
    rm -rf packages/ .theos/ obj/ layout/
    log_success "Clean complete"
}

build_project() {
    log_info "Building AIClient..."
    make DEBUG=0 FINALPACKAGE=1
    log_success "Build complete"
}

build_debug() {
    log_info "Building AIClient (Debug)..."
    make DEBUG=1
    log_success "Debug build complete"
}

package_deb() {
    log_info "Creating .deb package..."
    make package FINALPACKAGE=1
    if [ -d "packages" ]; then
        ls -la packages/
        log_success "Package created in packages/"
    fi
}

install_device() {
    log_info "Installing to device via SSH..."
    make install
    log_success "Installed to device"
}

build_xcodeproj() {
    log_info "Generating Xcode project..."
    make xcodeproj
    if [ -f "AIClient.xcodeproj/project.pbxproj" ]; then
        log_success "Xcode project generated"
    fi
}

run_simulator() {
    log_info "Building for simulator..."
    export TARGET=simulator:clang:16.5:15.0
    make DEBUG=1
    log_success "Simulator build complete"
}

show_help() {
    echo "AIClient Build Script"
    echo ""
    echo "Usage: ./build.sh [command]"
    echo ""
    echo "Commands:"
    echo "  clean         Clean build artifacts"
    echo "  build         Build release version"
    echo "  debug         Build debug version"
    echo "  package       Create .deb package"
    echo "  install       Install to connected device via SSH"
    echo "  xcodeproj     Generate Xcode project"
    echo "  simulator     Build for iOS Simulator"
    echo "  all           Clean, build, and package"
    echo "  help          Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  THEOS         Path to theos installation (default: /opt/theos or ~/theos)"
    echo "  TARGET        Build target (default: iphone:clang:16.5:13.0)"
}

# Main
check_theos
check_ldid

case "${1:-help}" in
    clean)
        clean_build
        ;;
    build)
        build_project
        ;;
    debug)
        build_debug
        ;;
    package)
        package_deb
        ;;
    install)
        install_device
        ;;
    xcodeproj)
        build_xcodeproj
        ;;
    simulator)
        run_simulator
        ;;
    all)
        clean_build
        build_project
        package_deb
        ;;
    help|*)
        show_help
        ;;
esac