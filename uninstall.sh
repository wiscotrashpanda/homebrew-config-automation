#!/usr/bin/env bash
#
# Homebrew Configuration Management - Uninstallation Script
# Removes all installed components from the system
#
# Version: 1.0.0
#

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Installation paths (matching install.sh)
INSTALL_DIR="${HOME}/bin"
CONFIG_DIR="${HOME}/.config/homebrew-config"
LOG_DIR="${HOME}/.local/share/homebrew-config"
APP_BUNDLE="${HOME}/Applications/Homebrew Config Automation.app"
PLIST_FILE="${HOME}/Library/LaunchAgents/com.emkaytec.homebrewconfig.plist"
PLIST_LABEL="com.emkaytec.homebrewconfig"

# Track what was removed
declare -a REMOVED_ITEMS=()
declare -a FAILED_ITEMS=()

#######################################
# Display uninstallation help message
# Arguments:
#   None
# Outputs:
#   Help text to stdout
#######################################
show_help() {
    cat << EOF
Homebrew Configuration Management - Uninstallation Script v${SCRIPT_VERSION}

Removes all installed components from the system.

USAGE:
    uninstall.sh [OPTIONS]

OPTIONS:
    -h, --help             Show this help message
    -y, --yes              Skip confirmation prompt

WHAT THIS SCRIPT REMOVES:
    - Launchd job (if loaded)
    - Application bundle from ~/Applications/
    - Launchd plist file
    - brew-config.sh script from ~/bin/
    - Configuration directory (~/.config/homebrew-config/)
    - Log directory (~/.local/share/homebrew-config/)

WHAT THIS SCRIPT PRESERVES:
    - Brewfile in destination directory (default: ~/Config/Brewfile)
    - Destination directory itself
    - Any other files in destination directory

EXAMPLES:
    # Uninstall with confirmation
    ./uninstall.sh
    
    # Uninstall without confirmation
    ./uninstall.sh --yes

EOF
}

#######################################
# Unload the launchd job if it is loaded
# Arguments:
#   None
# Returns:
#   0 on success or if not loaded, 1 on failure
#######################################
unload_launchd() {
    echo "Checking launchd job..."
    
    # Check if plist file exists
    if [[ ! -f "${PLIST_FILE}" ]]; then
        echo "  Plist file not found, skipping"
        return 0
    fi
    
    # Check if job is loaded
    if launchctl list | grep -q "${PLIST_LABEL}"; then
        echo "  Unloading launchd job: ${PLIST_LABEL}"
        if launchctl unload "${PLIST_FILE}" 2>/dev/null; then
            echo "  ✓ Launchd job unloaded"
            REMOVED_ITEMS+=("Launchd job (${PLIST_LABEL})")
        else
            echo "  ERROR: Failed to unload launchd job" >&2
            FAILED_ITEMS+=("Launchd job (${PLIST_LABEL})")
            return 1
        fi
    else
        echo "  Launchd job not loaded, skipping"
    fi
    
    return 0
}

#######################################
# Remove application bundle from ~/Applications/
# Arguments:
#   None
# Returns:
#   0 on success or if not present, 1 on failure
#######################################
remove_app_bundle() {
    echo "Removing application bundle..."
    
    if [[ ! -d "${APP_BUNDLE}" ]]; then
        echo "  Application bundle not found, skipping"
        return 0
    fi
    
    if rm -rf "${APP_BUNDLE}" 2>/dev/null; then
        echo "  ✓ Application bundle removed: ${APP_BUNDLE}"
        REMOVED_ITEMS+=("Application bundle")
    else
        echo "  ERROR: Failed to remove application bundle: ${APP_BUNDLE}" >&2
        FAILED_ITEMS+=("Application bundle")
        return 1
    fi
    
    return 0
}

#######################################
# Remove launchd plist file
# Arguments:
#   None
# Returns:
#   0 on success or if not present, 1 on failure
#######################################
remove_plist() {
    echo "Removing launchd plist..."
    
    if [[ ! -f "${PLIST_FILE}" ]]; then
        echo "  Plist file not found, skipping"
        return 0
    fi
    
    if rm -f "${PLIST_FILE}" 2>/dev/null; then
        echo "  ✓ Plist file removed: ${PLIST_FILE}"
        REMOVED_ITEMS+=("Launchd plist file")
    else
        echo "  ERROR: Failed to remove plist file: ${PLIST_FILE}" >&2
        FAILED_ITEMS+=("Launchd plist file")
        return 1
    fi
    
    return 0
}

#######################################
# Remove brew-config.sh script from installation location
# Arguments:
#   None
# Returns:
#   0 on success or if not present, 1 on failure
#######################################
remove_script() {
    echo "Removing brew-config.sh script..."
    
    local script_path="${INSTALL_DIR}/brew-config.sh"
    
    if [[ ! -f "${script_path}" ]]; then
        echo "  Script not found, skipping"
        return 0
    fi
    
    if rm -f "${script_path}" 2>/dev/null; then
        echo "  ✓ Script removed: ${script_path}"
        REMOVED_ITEMS+=("brew-config.sh script")
    else
        echo "  ERROR: Failed to remove script: ${script_path}" >&2
        FAILED_ITEMS+=("brew-config.sh script")
        return 1
    fi
    
    return 0
}

#######################################
# Remove configuration directory and files
# Arguments:
#   None
# Returns:
#   0 on success or if not present, 1 on failure
#######################################
remove_config() {
    echo "Removing configuration directory..."
    
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        echo "  Configuration directory not found, skipping"
        return 0
    fi
    
    if rm -rf "${CONFIG_DIR}" 2>/dev/null; then
        echo "  ✓ Configuration directory removed: ${CONFIG_DIR}"
        REMOVED_ITEMS+=("Configuration directory")
    else
        echo "  ERROR: Failed to remove configuration directory: ${CONFIG_DIR}" >&2
        FAILED_ITEMS+=("Configuration directory")
        return 1
    fi
    
    return 0
}

#######################################
# Remove log directory and all log files
# Arguments:
#   None
# Returns:
#   0 on success or if not present, 1 on failure
#######################################
remove_logs() {
    echo "Removing log directory..."
    
    if [[ ! -d "${LOG_DIR}" ]]; then
        echo "  Log directory not found, skipping"
        return 0
    fi
    
    if rm -rf "${LOG_DIR}" 2>/dev/null; then
        echo "  ✓ Log directory removed: ${LOG_DIR}"
        REMOVED_ITEMS+=("Log directory")
    else
        echo "  ERROR: Failed to remove log directory: ${LOG_DIR}" >&2
        FAILED_ITEMS+=("Log directory")
        return 1
    fi
    
    return 0
}

#######################################
# Verify that all components have been removed
# Arguments:
#   None
# Returns:
#   0 if all removed, 1 if any remain
#######################################
verify_uninstallation() {
    echo "Verifying uninstallation..."
    
    local verification_failed=false
    
    # Check if script still exists
    if [[ -f "${INSTALL_DIR}/brew-config.sh" ]]; then
        echo "  WARNING: Script still exists: ${INSTALL_DIR}/brew-config.sh" >&2
        verification_failed=true
    fi
    
    # Check if app bundle still exists
    if [[ -d "${APP_BUNDLE}" ]]; then
        echo "  WARNING: Application bundle still exists: ${APP_BUNDLE}" >&2
        verification_failed=true
    fi
    
    # Check if plist still exists
    if [[ -f "${PLIST_FILE}" ]]; then
        echo "  WARNING: Plist file still exists: ${PLIST_FILE}" >&2
        verification_failed=true
    fi
    
    # Check if config directory still exists
    if [[ -d "${CONFIG_DIR}" ]]; then
        echo "  WARNING: Configuration directory still exists: ${CONFIG_DIR}" >&2
        verification_failed=true
    fi
    
    # Check if log directory still exists
    if [[ -d "${LOG_DIR}" ]]; then
        echo "  WARNING: Log directory still exists: ${LOG_DIR}" >&2
        verification_failed=true
    fi
    
    # Check if launchd job is still loaded
    if launchctl list | grep -q "${PLIST_LABEL}"; then
        echo "  WARNING: Launchd job still loaded: ${PLIST_LABEL}" >&2
        verification_failed=true
    fi
    
    if [[ "${verification_failed}" == true ]]; then
        echo "  Some components could not be removed"
        return 1
    fi
    
    echo "  ✓ All components successfully removed"
    return 0
}

#######################################
# Display summary of what was removed
# Arguments:
#   None
# Outputs:
#   Summary to stdout
#######################################
display_summary() {
    echo "=========================================="
    echo "Uninstallation Summary"
    echo "=========================================="
    echo
    
    if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
        echo "Successfully removed:"
        for item in "${REMOVED_ITEMS[@]}"; do
            echo "  ✓ ${item}"
        done
        echo
    fi
    
    if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
        echo "Failed to remove:"
        for item in "${FAILED_ITEMS[@]}"; do
            echo "  ✗ ${item}"
        done
        echo
    fi
    
    echo "Preserved items:"
    echo "  ✓ Brewfile in destination directory"
    echo "  ✓ Destination directory"
    echo
    
    if [[ ${#FAILED_ITEMS[@]} -eq 0 ]]; then
        echo "Uninstallation completed successfully!"
    else
        echo "Uninstallation completed with errors"
        echo "Some components may need to be removed manually"
    fi
    echo
}

#######################################
# Main uninstallation function
# Orchestrates the uninstallation process
# Arguments:
#   $@ - Command-line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
main() {
    local skip_confirmation=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -y|--yes)
                skip_confirmation=true
                shift
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    echo "=========================================="
    echo "Homebrew Configuration Management"
    echo "Uninstallation Script v${SCRIPT_VERSION}"
    echo "=========================================="
    echo
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "ERROR: This script is designed for macOS only" >&2
        exit 1
    fi
    
    # Show what will be removed
    echo "This script will remove the following components:"
    echo "  - Launchd job (if loaded)"
    echo "  - Application bundle: ${APP_BUNDLE}"
    echo "  - Launchd plist: ${PLIST_FILE}"
    echo "  - Script: ${INSTALL_DIR}/brew-config.sh"
    echo "  - Configuration: ${CONFIG_DIR}"
    echo "  - Logs: ${LOG_DIR}"
    echo
    echo "The following will be PRESERVED:"
    echo "  - Brewfile in destination directory"
    echo "  - Destination directory itself"
    echo
    
    # Confirmation prompt
    if [[ "${skip_confirmation}" == false ]]; then
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Uninstallation cancelled"
            exit 0
        fi
        echo
    fi
    
    # Unload launchd job (continue on failure)
    unload_launchd || true
    
    # Remove application bundle (continue on failure)
    remove_app_bundle || true
    
    # Remove plist file (continue on failure)
    remove_plist || true
    
    # Remove script (continue on failure)
    remove_script || true
    
    # Remove configuration directory (continue on failure)
    remove_config || true
    
    # Remove log directory (continue on failure)
    remove_logs || true
    
    echo
    
    # Verify uninstallation
    verify_uninstallation || true
    
    echo
    
    # Display summary
    display_summary
    
    # Exit with error if any items failed to remove
    if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"
